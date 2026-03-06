// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IReputationRegistry
 * @notice Tracks provider reputation scores with bounded counterparty gains
 * @dev Phase 0: score-only tracking, no slashing. INV-5 enforcement.
 */
interface IReputationRegistry {
    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Emitted when a provider's reputation is updated
     * @param provider Provider whose reputation changed
     * @param newScore New total score (0-1000)
     * @param delta Change in score (can be positive or negative in future)
     * @param payer Payer who contributed to this update
     * @param epochStart Start of the epoch in which this gain occurred
     */
    event ReputationUpdated(
        address indexed provider, uint16 newScore, int16 delta, address indexed payer, uint256 epochStart
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════

    error OnlyEscrow();
    error ScoreOverflow();
    error CounterpartyCapExceeded();

    // ══════════════════════════════════════════════════════════════════════════════
    // External Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Record a successful settlement for a provider
     * @dev Only callable by AgentEscrow. Enforces INV-5 counterparty cap.
     * @param provider Provider who successfully completed service
     * @param payer Payer who received service
     * @param gain Reputation points to add (before cap enforcement)
     */
    function recordSuccess(address provider, address payer, uint16 gain) external;

    /**
     * @notice Get provider's current reputation score
     * @param provider Provider address
     * @return score Current reputation score (0-1000)
     */
    function getScore(address provider) external view returns (uint16 score);

    /**
     * @notice Get gains from a specific payer in current epoch
     * @param provider Provider address
     * @param payer Payer address
     * @return gains Total gains from this payer in current epoch
     */
    function getCounterpartyGains(address provider, address payer) external view returns (uint16 gains);

    /**
     * @notice Get the current epoch start timestamp
     * @return epochStart Start of current epoch
     */
    function getCurrentEpoch() external view returns (uint256 epochStart);
}
