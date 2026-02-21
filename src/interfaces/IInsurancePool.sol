// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IInsurancePool
 * @notice Insurance pool with deterministic bucket-based caps (INV-3)
 * @dev Phase 0: Claim authorization from escrow, payer execution, age ramp, bucket snapshots
 */
interface IInsurancePool {
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Structs
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Insurance claim state
     * @param payer Payer who can execute claim
     * @param provider Provider (for tracking)
     * @param token Token to pay out
     * @param requestedAmount Authorized amount (not guaranteed due to caps)
     * @param authorizedAt Timestamp of authorization
     * @param status Current claim status
     */
    struct Claim {
        address payer;
        address provider;
        address token;
        uint128 requestedAmount;
        uint64 authorizedAt;
        ClaimStatus status;
    }
    
    /**
     * @notice Bucket for tracking payouts per epoch/day
     * @param openingBalance Pool balance at start of bucket (snapshot once)
     * @param paid Amount paid out in this bucket
     */
    struct Bucket {
        uint128 openingBalance;
        uint128 paid;
    }
    
    enum ClaimStatus {
        UNAUTHORIZED,
        AUTHORIZED,
        CLAIMED,
        EXPIRED
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════
    
    event PoolDeposited(address indexed token, address indexed from, uint256 amount);
    event InsuranceClaimAuthorized(
        bytes32 indexed claimId,
        bytes32 indexed intentId,
        address indexed payer,
        address provider,
        address token,
        uint128 requestedAmount,
        uint64 authorizedAt
    );
    event InsuranceClaimPaid(
        bytes32 indexed claimId,
        bytes32 indexed intentId,
        address indexed payer,
        address token,
        uint256 amount,
        uint256 epochStart,
        uint256 dayStart
    );
    event InsuranceClaimExpired(bytes32 indexed claimId, bytes32 indexed intentId);
    event BucketOpened(address indexed token, string bucketType, uint256 bucketStart, uint128 openingBalance);
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════
    
    error OnlyEscrow();
    error OnlyStakeManagerOrEscrow();
    error OnlyPayer();
    error ClaimAlreadyAuthorized();
    error ClaimNotAuthorized();
    error ClaimExpired();
    error TokenNotSupported();
    error InsufficientPoolBalance();
    error EpochCapExceeded();
    error DayCapExceeded();
    error ProviderDayCapExceeded();
    error PayerEpochCapExceeded();
    error PayerAgeCapExceeded();
    error ZeroAmount();
    error InvalidAmount();
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Permissionless Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Deposit tokens to pool (permissionless)
     * @param token Token to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external;
    
    /**
     * @notice Expire an old authorized claim (permissionless)
     * @param claimId Claim identifier
     */
    function expireClaim(bytes32 claimId) external;
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Authorize an insurance claim (only escrow)
     * @dev Called during dispute resolution. Does not execute payout.
     * @param intentId Intent identifier
     * @param payer Payer who can execute claim
     * @param provider Provider (for tracking)
     * @param token Token for payout
     * @param requestedAmount Amount requested (must be ≤ intent.amount)
     * @param intentAmount Intent amount (for defensive bound check)
     * @return claimId Generated claim identifier
     */
    function authorizeClaim(
        bytes32 intentId,
        address payer,
        address provider,
        address token,
        uint128 requestedAmount,
        uint128 intentAmount
    ) external returns (bytes32 claimId);
    
    // ══════════════════════════════════════════════════════════════════════════════
    // StakeManager/Escrow Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Notify pool of direct token transfer (push deposit)
     * @dev Called by StakeManager.slash() or AgentEscrow bond slashing
     * @dev Tokens already transferred; this updates accounting only
     * @param token Token that was transferred
     * @param amount Amount that was transferred
     */
    function notifyDepositFromStake(address token, uint256 amount) external;
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Payer Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Execute an authorized claim (only payer)
     * @dev Enforces all caps (INV-3) in order. Reverts if any cap exceeded.
     * @param intentId Intent identifier (convenience wrapper)
     */
    function claim(bytes32 intentId) external;
    
    /**
     * @notice Execute an authorized claim by claimId (only payer)
     * @param claimId Claim identifier
     */
    function claimById(bytes32 claimId) external;
    
   
    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════
    
    function poolBalance(address token) external view returns (uint256);
    
    // Note: claims() returns Claim struct fields, not Claim memory
    // This matches Solidity's auto-generated getter for public mappings
    function claims(bytes32 claimId) external view returns (
        address payer,
        address provider,
        address token,
        uint128 requestedAmount,
        uint64 authorizedAt,
        ClaimStatus status
    );
    
    function claimIdByIntent(bytes32 intentId) external view returns (bytes32);
    
    // Note: Bucket getters return struct fields, not Bucket memory
    function epochBucket(address token, uint256 epochStart) external view returns (
        uint128 openingBalance,
        uint128 paid
    );
    
    function dayBucket(address token, uint256 dayStart) external view returns (
        uint128 openingBalance,
        uint128 paid
    );
    
    function providerDayPaid(address token, address provider, uint256 dayStart) external view returns (uint256);
    function payerEpochPaid(address token, address payer, uint256 epochStart) external view returns (uint256);
    function MAX_PAYER_PAYOUT_PER_TOKEN(address token) external view returns (uint256);
    
    function escrow() external view returns (address);
    function stakeManager() external view returns (address);
    
    function EPOCH_SECONDS() external view returns (uint256);
    function DAY_SECONDS() external view returns (uint256);
    function RAMP_SECONDS() external view returns (uint256);
    function CLAIM_TTL() external view returns (uint256);

    // Convenience getters (return structs instead of tuples)
    function getClaim(bytes32 claimId) external view returns (Claim memory);
    function getEpochBucket(address token, uint256 epochStart) external view returns (Bucket memory);
    function getDayBucket(address token, uint256 dayStart) external view returns (Bucket memory);
}