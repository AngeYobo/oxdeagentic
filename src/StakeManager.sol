// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {IInsurancePool} from "./interfaces/IInsurancePool.sol";

/**
 * @title StakeManager
 * @notice Manages provider stake with bounded slashing (INV-1)
 * @dev Phase 0: Lock/unlock primitives only. No automatic slashing policy.
 *
 * Invariants:
 * - INV-1: Slash ≤50% of locked stake (hard revert, never clamp)
 * - totalStake = lockedStake + availableStake (always)
 * - Intent locks are unique (no double-lock)
 * - Only ESCROW can lock/unlock/slash
 *
 * Security:
 * - Immutable dependencies (ESCROW, INSURANCE_POOL)
 * - ReentrancyGuard on deposit/withdraw
 * - SafeERC20 for token transfers
 * - Access control via onlyEscrow modifier
 */
contract StakeManager is IStakeManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constants
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Maximum slash percentage (50% = 5000 basis points)
    uint16 public constant MAX_SLASH_BPS = 5000;

    /// @notice Basis points denominator
    uint16 private constant BPS_DENOMINATOR = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // Immutable State
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice AgentEscrow contract (only authorized caller)
    address public immutable ESCROW;

    /// @notice InsurancePool contract (receives slashed funds)
    address public immutable INSURANCE_POOL;

    // ══════════════════════════════════════════════════════════════════════════════
    // Storage
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Total stake per provider per token
    /// @dev provider => token => amount
    mapping(address => mapping(address => uint256)) private _totalStake;

    /// @notice Locked stake per provider per token
    /// @dev provider => token => amount
    mapping(address => mapping(address => uint256)) private _lockedStake;

    /// @notice Intent-specific locks
    /// @dev intentId => StakeLock
    mapping(bytes32 => StakeLock) private _intentLocks;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Initialize StakeManager with immutable dependencies
     * @param _escrow AgentEscrow contract address
     * @param _insurancePool InsurancePool contract address
     */
    constructor(address _escrow, address _insurancePool) {
        if (_escrow == address(0)) revert ZeroAddress();
        if (_insurancePool == address(0)) revert ZeroAddress();

        ESCROW = _escrow;
        INSURANCE_POOL = _insurancePool;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Modifiers
    // ══════════════════════════════════════════════════════════════════════════════

    modifier onlyEscrow() {
        _onlyEscrow();
        _;
    }

    function _onlyEscrow() internal view {
        if (msg.sender != ESCROW) revert OnlyEscrow();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Provider Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IStakeManager
     * @dev Uses SafeERC20 for token transfers
     * @dev Protected by ReentrancyGuard
     */
    function depositStake(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        address provider = msg.sender;

        // Update accounting before transfer (CEI)
        _totalStake[provider][token] += amount;

        // Transfer tokens from provider
        IERC20(token).safeTransferFrom(provider, address(this), amount);

        emit StakeDeposited(provider, token, amount);
    }

    /**
     * @inheritdoc IStakeManager
     * @dev Only allows withdrawal of available (unlocked) stake
     * @dev Protected by ReentrancyGuard
     */
    function withdrawStake(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        address provider = msg.sender;

        uint256 available = availableStake(provider, token);
        if (amount > available) revert InsufficientStake();

        // Update accounting before transfer (CEI)
        _totalStake[provider][token] -= amount;

        // Transfer tokens to provider
        IERC20(token).safeTransfer(provider, amount);

        emit StakeWithdrawn(provider, token, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IStakeManager
     * @dev Reverts if insufficient available stake
     * @dev Prevents double-locking same intentId
     */
    function lockStake(address provider, address token, uint256 amount, bytes32 intentId) external onlyEscrow {
        if (provider == address(0)) revert ZeroAddress();
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (intentId == bytes32(0)) revert ZeroAddress();

        // Check lock doesn't already exist
        if (_intentLocks[intentId].active) revert LockAlreadyExists();

        // Check sufficient available stake
        uint256 available = availableStake(provider, token);
        if (amount > available) revert InsufficientStake();

        // Create lock
        _intentLocks[intentId] = StakeLock({
            provider: provider,
            token: token,
            // forge-lint: disable-next-line(unsafe-typecast)
            amount: uint96(amount), // Safe: checked in ESCROW
            active: true
        });

        // Update locked accounting
        _lockedStake[provider][token] += amount;

        emit StakeLocked(intentId, provider, token, amount);
    }

    /**
     * @inheritdoc IStakeManager
     * @dev Idempotent - safe to call multiple times (no-op if already unlocked)
     */
    function unlockStake(bytes32 intentId) external onlyEscrow {
        StakeLock storage lock = _intentLocks[intentId];

        // Idempotent: if lock doesn't exist or already inactive, no-op
        if (!lock.active) return;

        address provider = lock.provider;
        address token = lock.token;
        uint256 amount = lock.amount;

        // Mark inactive before updating accounting (prevents reentrancy issues)
        lock.active = false;

        // Update locked accounting
        _lockedStake[provider][token] -= amount;

        emit StakeUnlocked(intentId, provider, token, amount);
    }

    /**
     * @inheritdoc IStakeManager
     * @dev INV-1: MUST revert if amount > 50% of locked stake (never clamp)
     * @dev Transfers slashed amount to InsurancePool and calls notifyDepositFromStake
     */
    function slash(bytes32 intentId, uint256 amount) external onlyEscrow {
        if (amount == 0) revert ZeroAmount();

        StakeLock storage lock = _intentLocks[intentId];

        if (lock.provider == address(0)) revert LockNotFound();
        if (!lock.active) revert LockNotActive();

        // INV-1: Enforce 50% cap (MUST revert, never clamp)
        uint256 maxSlash = (uint256(lock.amount) * MAX_SLASH_BPS) / BPS_DENOMINATOR;
        if (amount > maxSlash) revert SlashExceedsCap();

        address provider = lock.provider;
        address token = lock.token;

        // Update accounting before transfers (CEI)
        _totalStake[provider][token] -= amount;
        _lockedStake[provider][token] -= amount;
        // forge-lint: disable-next-line(unsafe-typecast)
        lock.amount -= uint96(amount); // Safe: amount <= lock.amount by cap check

        // Transfer slashed tokens to InsurancePool
        IERC20(token).safeTransfer(INSURANCE_POOL, amount);

        // Notify InsurancePool of accounting (no transferFrom)
        IInsurancePool(INSURANCE_POOL).notifyDepositFromStake(token, amount);

        emit StakeSlashed(intentId, provider, token, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IStakeManager
     */
    function totalStake(address provider, address token) external view returns (uint256) {
        return _totalStake[provider][token];
    }

    /**
     * @inheritdoc IStakeManager
     */
    function lockedStake(address provider, address token) external view returns (uint256) {
        return _lockedStake[provider][token];
    }

    /**
     * @inheritdoc IStakeManager
     */
    function availableStake(address provider, address token) public view returns (uint256) {
        uint256 total = _totalStake[provider][token];
        uint256 locked = _lockedStake[provider][token];

        // Safe: locked can never exceed total
        unchecked {
            return total - locked;
        }
    }

    /**
     * @inheritdoc IStakeManager
     */
    function intentLocks(bytes32 intentId) external view returns (StakeLock memory) {
        return _intentLocks[intentId];
    }

    /**
     * @inheritdoc IStakeManager
     */
    function escrow() external view returns (address) {
        return ESCROW;
    }

    /**
     * @inheritdoc IStakeManager
     */
    function insurancePool() external view returns (address) {
        return INSURANCE_POOL;
    }
}
