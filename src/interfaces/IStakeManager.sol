// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IStakeManager
 * @notice Manages provider stake deposits, locks, and bounded slashing
 * @dev Phase 0: Lock/unlock only. Slashing primitive exists but no policy triggers.
 *      INV-1: Slash cap ≤50% of locked stake (hard revert, never clamp)
 */
interface IStakeManager {
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Structs
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Intent-specific stake lock
     * @param provider Provider whose stake is locked
     * @param token Token being locked
     * @param amount Amount locked for this intent
     * @param active Whether lock is currently active
     */
    struct StakeLock {
        address provider;
        address token;
        uint96 amount;
        bool active;
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════
    
    event StakeDeposited(address indexed provider, address indexed token, uint256 amount);
    event StakeWithdrawn(address indexed provider, address indexed token, uint256 amount);
    event StakeLocked(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    event StakeUnlocked(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    event StakeSlashed(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════
    
    error OnlyEscrow();
    error InsufficientStake();
    error LockAlreadyExists();
    error LockNotFound();
    error LockNotActive();
    error SlashExceedsCap();
    error ZeroAmount();
    error ZeroAddress();
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Provider Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Deposit stake for a token
     * @param token ERC20 token to stake
     * @param amount Amount to deposit
     */
    function depositStake(address token, uint256 amount) external;
    
    /**
     * @notice Withdraw available (unlocked) stake
     * @param token ERC20 token to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawStake(address token, uint256 amount) external;
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Lock stake for an intent (fastMode)
     * @dev Only callable by escrow. Reverts if insufficient available stake.
     * @param provider Provider whose stake to lock
     * @param token Token to lock
     * @param amount Amount to lock (typically 3x intent amount)
     * @param intentId Intent identifier for this lock
     */
    function lockStake(
        address provider,
        address token,
        uint256 amount,
        bytes32 intentId
    ) external;
    
    /**
     * @notice Unlock stake for an intent
     * @dev Only callable by escrow. Called on terminal states.
     * @param intentId Intent identifier
     */
    function unlockStake(bytes32 intentId) external;
    
    /**
     * @notice Slash locked stake (bounded by INV-1)
     * @dev Only callable by escrow. Reverts if amount > 50% of locked stake.
     * @dev Transfers slashed amount to InsurancePool and calls notifyDepositFromStake.
     * @param intentId Intent identifier
     * @param amount Amount to slash (must be ≤ 50% of locked amount)
     */
    function slash(bytes32 intentId, uint256 amount) external;
    
    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Get total stake for provider and token
     * @param provider Provider address
     * @param token Token address
     * @return Total staked amount
     */
    function totalStake(address provider, address token) external view returns (uint256);
    
    /**
     * @notice Get locked stake for provider and token
     * @param provider Provider address
     * @param token Token address
     * @return Currently locked amount
     */
    function lockedStake(address provider, address token) external view returns (uint256);
    
    /**
     * @notice Get available (unlocked) stake
     * @param provider Provider address
     * @param token Token address
     * @return Available amount for withdrawal or locking
     */
    function availableStake(address provider, address token) external view returns (uint256);
    
    /**
     * @notice Get lock details for an intent
     * @param intentId Intent identifier
     * @return lock StakeLock struct
     */
    function intentLocks(bytes32 intentId) external view returns (StakeLock memory lock);
    
    /**
     * @notice Get immutable escrow address
     * @return Escrow contract address
     */
    function escrow() external view returns (address);
    
    /**
     * @notice Get immutable insurance pool address
     * @return InsurancePool contract address
     */
    function insurancePool() external view returns (address);
    
    /**
     * @notice Maximum slash percentage (50% = 5000 bps)
     * @return Max slash in basis points
     */
    function MAX_SLASH_BPS() external view returns (uint16);
}