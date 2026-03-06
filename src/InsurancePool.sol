// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IInsurancePool} from "./interfaces/IInsurancePool.sol";
import {IAgentEscrow} from "./interfaces/IAgentEscrow.sol";

/**
 * @title InsurancePool
 * @notice Insurance pool with deterministic bucket-based caps (INV-3)
 * @dev Phase 0: Bucket snapshots, age ramp, claim authorization from escrow
 *
 * Invariants:
 * - INV-3: Multi-tier caps (epoch/day/provider-day/payer-epoch/age-adjusted absolute)
 * - Bucket opening balance snapshots are immutable (set once)
 * - Claims are one-shot (AUTHORIZED → CLAIMED)
 * - Age ramp: 0→100% over 30 days
 * - Claims expire after 90 days
 *
 * Security:
 * - Immutable dependencies (escrow, stakeManager)
 * - ReentrancyGuard on deposit/claim
 * - SafeERC20 for all transfers
 * - Strict access control (onlyEscrow, onlyStakeManagerOrEscrow)
 * - CEI pattern throughout
 */
contract InsurancePool is IInsurancePool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constants
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Epoch duration (28 days)
    uint256 public constant EPOCH_SECONDS = 28 days;

    /// @notice Day duration (24 hours)
    uint256 public constant DAY_SECONDS = 1 days;

    /// @notice Payer age ramp duration (30 days, 0→100%)
    uint256 public constant RAMP_SECONDS = 30 days;

    /// @notice Claim time-to-live (90 days)
    uint256 public constant CLAIM_TTL = 90 days;

    /// @notice Cached chain ID for claim ID generation
    uint256 public immutable CHAIN_ID;

    // Cap percentages (in basis points, 10000 = 100%)
    uint16 private constant EPOCH_CAP_BPS = 1000; // 10%
    uint16 private constant DAY_CAP_BPS = 250; // 2.5%
    uint16 private constant PROVIDER_DAY_CAP_BPS = 3000; // 30%
    uint16 private constant PAYER_EPOCH_CAP_BPS = 100; // 1%
    uint16 private constant BPS_DENOMINATOR = 10_000;

    // ══════════════════════════════════════════════════════════════════════════════
    // Immutable State
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice AgentEscrow contract (claim authorizer + firstSeen oracle)
    address public immutable escrow;

    /// @notice StakeManager contract (authorized depositor)
    address public immutable stakeManager;

    // ══════════════════════════════════════════════════════════════════════════════
    // Storage
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Pool balance per token
    mapping(address => uint256) public poolBalance;

    /// @notice Maximum payout per token (0 = unsupported)
    mapping(address => uint256) public MAX_PAYER_PAYOUT_PER_TOKEN;

    /// @notice Epoch buckets per token
    mapping(address => mapping(uint256 => Bucket)) public epochBucket;

    /// @notice Day buckets per token
    mapping(address => mapping(uint256 => Bucket)) public dayBucket;

    /// @notice Provider-day paid amounts
    mapping(address => mapping(address => mapping(uint256 => uint256))) public providerDayPaid;

    /// @notice Payer-epoch paid amounts
    mapping(address => mapping(address => mapping(uint256 => uint256))) public payerEpochPaid;

    /// @notice Claims by claimId
    mapping(bytes32 => Claim) public claims;

    /// @notice Convenience mapping: intentId → claimId
    mapping(bytes32 => bytes32) public claimIdByIntent;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Initialize InsurancePool with immutable dependencies
     * @param _escrow AgentEscrow contract address
     * @param _stakeManager StakeManager contract address
     */
    constructor(address _escrow, address _stakeManager) {
        if (_escrow == address(0)) revert InvalidAmount();
        if (_stakeManager == address(0)) revert InvalidAmount();

        escrow = _escrow;
        stakeManager = _stakeManager;
        CHAIN_ID = block.chainid;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Modifiers
    // ══════════════════════════════════════════════════════════════════════════════

    modifier onlyEscrow() {
        _onlyEscrow();
        _;
    }

    function _onlyEscrow() internal view {
        if (msg.sender != escrow) revert OnlyEscrow();
    }

    modifier onlyStakeManagerOrEscrow() {
        _onlyStakeManagerOrEscrow();
        _;
    }

    function _onlyStakeManagerOrEscrow() internal view {
        if (msg.sender != stakeManager && msg.sender != escrow) {
            revert OnlyStakeManagerOrEscrow();
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Permissionless Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IInsurancePool
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert ZeroAmount();
        if (amount == 0) revert ZeroAmount();

        // Update balance before transfer (CEI)
        poolBalance[token] += amount;

        // Transfer tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit PoolDeposited(token, msg.sender, amount);
    }

    /**
     * @inheritdoc IInsurancePool
     */
    function expireClaim(bytes32 claimId) external {
        Claim storage claimData = claims[claimId];

        if (claimData.status != ClaimStatus.AUTHORIZED) revert ClaimNotAuthorized();
        if (block.timestamp <= claimData.authorizedAt + CLAIM_TTL) revert ClaimExpired();

        claimData.status = ClaimStatus.EXPIRED;

        emit InsuranceClaimExpired(claimId, _intentIdFromClaimId(claimId));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IInsurancePool
     */
    function authorizeClaim(
        bytes32 intentId,
        address payer,
        address provider,
        address token,
        uint128 requestedAmount,
        uint128 intentAmount
    ) external onlyEscrow returns (bytes32 claimId) {
        // Validation
        if (requestedAmount == 0) revert ZeroAmount();
        if (requestedAmount > intentAmount) revert InvalidAmount();
        if (MAX_PAYER_PAYOUT_PER_TOKEN[token] == 0) revert TokenNotSupported();

        // Generate claimId
        claimId = _generateClaimId(intentId);

        // Check claim doesn't already exist
        if (claims[claimId].status != ClaimStatus.UNAUTHORIZED) {
            revert ClaimAlreadyAuthorized();
        }

        // Create claim
        claims[claimId] = Claim({
            payer: payer,
            provider: provider,
            token: token,
            requestedAmount: requestedAmount,
            authorizedAt: uint64(block.timestamp),
            status: ClaimStatus.AUTHORIZED
        });

        // Store convenience mapping
        claimIdByIntent[intentId] = claimId;

        emit InsuranceClaimAuthorized(
            claimId, intentId, payer, provider, token, requestedAmount, uint64(block.timestamp)
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // StakeManager/Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IInsurancePool
     */
    function notifyDepositFromStake(address token, uint256 amount) external onlyStakeManagerOrEscrow {
        if (amount == 0) revert ZeroAmount();

        // Update balance (tokens already transferred)
        poolBalance[token] += amount;

        emit PoolDeposited(token, msg.sender, amount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Payer Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IInsurancePool
     */
    function claim(bytes32 intentId) external nonReentrant {
        bytes32 claimId = claimIdByIntent[intentId];
        if (claimId == bytes32(0)) revert ClaimNotAuthorized();

        _executeClaim(claimId);
    }

    /**
     * @inheritdoc IInsurancePool
     */
    function claimById(bytes32 claimId) external nonReentrant {
        _executeClaim(claimId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Internal Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Execute a claim with full cap enforcement
     * @param claimId Claim identifier
     */
    function _executeClaim(bytes32 claimId) internal {
        Claim storage claimData = claims[claimId];

        // Validation
        if (msg.sender != claimData.payer) revert OnlyPayer();
        if (claimData.status != ClaimStatus.AUTHORIZED) revert ClaimNotAuthorized();
        if (block.timestamp > claimData.authorizedAt + CLAIM_TTL) {
            claimData.status = ClaimStatus.EXPIRED;
            revert ClaimExpired();
        }

        address token = claimData.token;
        uint256 requestedAmount = claimData.requestedAmount;

        // Check pool has sufficient balance
        if (poolBalance[token] < requestedAmount) revert InsufficientPoolBalance();

        // Get bucket timestamps
        uint256 epochStart = _bucketEpochStart(block.timestamp);
        uint256 dayStart = _bucketDayStart(block.timestamp);

        // Ensure buckets are initialized
        _ensureEpochBucket(token, epochStart);
        _ensureDayBucket(token, dayStart);

        // Enforce caps (INV-3) - MUST all pass or revert
        _enforceCaps(claimData, epochStart, dayStart, requestedAmount);

        // Update state before transfer (CEI)
        claimData.status = ClaimStatus.CLAIMED;

        // Update all counters
        // forge-lint: disable-next-line(unsafe-typecast)
        epochBucket[token][epochStart].paid += uint128(requestedAmount);
        // forge-lint: disable-next-line(unsafe-typecast)
        dayBucket[token][dayStart].paid += uint128(requestedAmount);
        providerDayPaid[token][claimData.provider][dayStart] += requestedAmount;
        payerEpochPaid[token][claimData.payer][epochStart] += requestedAmount;
        poolBalance[token] -= requestedAmount;

        // Transfer payout
        IERC20(token).safeTransfer(claimData.payer, requestedAmount);

        emit InsuranceClaimPaid(
            claimId, _intentIdFromClaimId(claimId), claimData.payer, token, requestedAmount, epochStart, dayStart
        );
    }

    /**
     * @notice Enforce all caps in order (INV-3)
     * @dev Reverts if any cap would be exceeded
     */
    function _enforceCaps(Claim storage claimData, uint256 epochStart, uint256 dayStart, uint256 requestedAmount)
        internal
        view
    {
        address token = claimData.token;

        // Cap 1: Epoch cap (10% of epoch opening balance)
        {
            uint256 epochOpeningBalance = epochBucket[token][epochStart].openingBalance;
            uint256 epochPaid = epochBucket[token][epochStart].paid;
            uint256 epochCap = (epochOpeningBalance * EPOCH_CAP_BPS) / BPS_DENOMINATOR;
            if (epochPaid + requestedAmount > epochCap) revert EpochCapExceeded();
        }

        // Cap 2: Day cap (2.5% of day opening balance)
        {
            uint256 dayOpeningBalance = dayBucket[token][dayStart].openingBalance;
            uint256 dayPaid = dayBucket[token][dayStart].paid;
            uint256 dayCap = (dayOpeningBalance * DAY_CAP_BPS) / BPS_DENOMINATOR;
            if (dayPaid + requestedAmount > dayCap) revert DayCapExceeded();
        }

        // Cap 3: Provider-day cap (30% of day opening balance)
        {
            uint256 dayOpeningBalance = dayBucket[token][dayStart].openingBalance;
            uint256 providerDayPaidAmount = providerDayPaid[token][claimData.provider][dayStart];
            uint256 providerDayCap = (dayOpeningBalance * PROVIDER_DAY_CAP_BPS) / BPS_DENOMINATOR;
            if (providerDayPaidAmount + requestedAmount > providerDayCap) {
                revert ProviderDayCapExceeded();
            }
        }

        // Cap 4: Payer-epoch cap (1% of epoch opening balance)
        {
            uint256 epochOpeningBalance = epochBucket[token][epochStart].openingBalance;
            uint256 payerEpochPaidAmount = payerEpochPaid[token][claimData.payer][epochStart];
            uint256 payerEpochCap = (epochOpeningBalance * PAYER_EPOCH_CAP_BPS) / BPS_DENOMINATOR;
            if (payerEpochPaidAmount + requestedAmount > payerEpochCap) {
                revert PayerEpochCapExceeded();
            }
        }

        // Cap 5: Age-adjusted absolute cap
        {
            uint256 ageAdjustedCap = _getAgeAdjustedCap(token, claimData.payer);
            if (requestedAmount > ageAdjustedCap) revert PayerAgeCapExceeded();
        }
    }

    /**
     * @notice Get age-adjusted cap for payer
     * @param token Token address
     * @param payer Payer address
     * @return Age-adjusted maximum payout
     */
    function _getAgeAdjustedCap(address token, address payer) internal view returns (uint256) {
        uint256 absoluteCap = MAX_PAYER_PAYOUT_PER_TOKEN[token];

        // Get firstSeen from escrow
        uint64 firstSeenTimestamp = IAgentEscrow(escrow).firstSeen(payer);

        // If never seen, 0% eligibility
        if (firstSeenTimestamp == 0) return 0;

        // If firstSeen is in the future (shouldn't happen but be defensive)
        if (firstSeenTimestamp > block.timestamp) return 0;

        // Calculate age
        uint256 age = block.timestamp - firstSeenTimestamp;

        // If age >= 30 days, 100% eligibility
        if (age >= RAMP_SECONDS) return absoluteCap;

        // Linear ramp: 0% → 100% over 30 days
        return (absoluteCap * age) / RAMP_SECONDS;
    }

    /**
     * @notice Ensure epoch bucket is initialized with opening balance
     * @param token Token address
     * @param epochStart Epoch start timestamp
     */
    function _ensureEpochBucket(address token, uint256 epochStart) internal {
        Bucket storage bucket = epochBucket[token][epochStart];

        // Only initialize once
        if (bucket.openingBalance == 0) {
            uint256 currentBalance = poolBalance[token];
            require(currentBalance > 0, "pool empty");

            // forge-lint: disable-next-line(unsafe-typecast)
            bucket.openingBalance = uint128(currentBalance);

            // forge-lint: disable-next-line(unsafe-typecast)
            emit BucketOpened(token, "epoch", epochStart, uint128(currentBalance));
        }
    }

    /**
     * @notice Ensure day bucket is initialized with opening balance
     * @param token Token address
     * @param dayStart Day start timestamp
     */
    function _ensureDayBucket(address token, uint256 dayStart) internal {
        Bucket storage bucket = dayBucket[token][dayStart];

        // Only initialize once
        if (bucket.openingBalance == 0) {
            uint256 currentBalance = poolBalance[token];
            require(currentBalance > 0, "pool empty");

            // forge-lint: disable-next-line(unsafe-typecast)
            bucket.openingBalance = uint128(currentBalance);

            // forge-lint: disable-next-line(unsafe-typecast)
            emit BucketOpened(token, "day", dayStart, uint128(currentBalance));
        }
    }

    /**
     * @notice Calculate epoch start for timestamp
     * @param timestamp Unix timestamp
     * @return Epoch start timestamp
     */
    function _bucketEpochStart(uint256 timestamp) internal pure returns (uint256) {
        // forge-lint: disable-next-line(divide-before-multiply)
        return (timestamp / EPOCH_SECONDS) * EPOCH_SECONDS;
    }

    /**
     * @notice Calculate day start for timestamp
     * @param timestamp Unix timestamp
     * @return Day start timestamp
     */
    function _bucketDayStart(uint256 timestamp) internal pure returns (uint256) {
        // forge-lint: disable-next-line(divide-before-multiply)
        return (timestamp / DAY_SECONDS) * DAY_SECONDS;
    }

    /**
     * @notice Generate deterministic claimId
     * @param intentId Intent identifier
     * @return claimId Claim identifier
     */
    function _generateClaimId(bytes32 intentId) internal view returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(CHAIN_ID, address(this), intentId));
    }

    /**
     * @notice Extract intentId from claimId (for events only, not security-critical)
     * @param claimId Claim identifier
     * @return intentId Intent identifier (best effort)
     */
    function _intentIdFromClaimId(bytes32 claimId) internal pure returns (bytes32) {
        // This is a convenience function for events
        // The actual intentId is stored in claimIdByIntent mapping
        // For events where we only have claimId, we can't reverse it
        // So we just return the claimId itself as a placeholder
        return claimId;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Governance Functions (Owner-only)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set maximum payout per token (governance only)
     * @dev This would be behind timelock in production
     * @param token Token address
     * @param maxPayout Maximum payout amount
     */
    function setMaxPayerPayoutPerToken(address token, uint256 maxPayout) external onlyEscrow {
        MAX_PAYER_PAYOUT_PER_TOKEN[token] = maxPayout;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Convenience View Functions (for cleaner external access)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Get claim as struct (convenience function for tests/external integrations)
     * @param claimId Claim identifier
     * @return Claim struct
     */
    function getClaim(bytes32 claimId) external view returns (Claim memory) {
        return claims[claimId];
    }

    /**
     * @notice Get epoch bucket as struct (convenience)
     * @param token Token address
     * @param epochStart Epoch start timestamp
     * @return Bucket struct
     */
    function getEpochBucket(address token, uint256 epochStart) external view returns (Bucket memory) {
        return epochBucket[token][epochStart];
    }

    /**
     * @notice Get day bucket as struct (convenience)
     * @param token Token address
     * @param dayStart Day start timestamp
     * @return Bucket struct
     */
    function getDayBucket(address token, uint256 dayStart) external view returns (Bucket memory) {
        return dayBucket[token][dayStart];
    }
}
