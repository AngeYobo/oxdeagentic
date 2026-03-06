// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";

/**
 * @title ReputationRegistry
 * @notice Tracks provider reputation with bounded counterparty gains (INV-5)
 * @dev Phase 0: Pure reputation tracking, no slashing. Immutable ESCROW reference.
 *
 * Invariants:
 * - INV-5: Max 50 points per counterparty per epoch (5% of 1000 max score)
 * - Score never exceeds 1000
 * - Only ESCROW can modify scores
 * - Epochs are deterministic (28 days)
 */
contract ReputationRegistry is IReputationRegistry {
    // ══════════════════════════════════════════════════════════════════════════════
    // Constants
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Maximum reputation score
    uint16 public constant MAX_SCORE = 1000;

    /// @notice Maximum gain from single counterparty per epoch (INV-5: 5% of max)
    uint16 public constant MAX_COUNTERPARTY_GAIN_PER_EPOCH = 50;

    /// @notice Epoch duration in seconds (28 days)
    uint256 public constant EPOCH_SECONDS = 28 days;

    // ══════════════════════════════════════════════════════════════════════════════
    // Immutable State
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice AgentEscrow contract (only authorized caller)
    address public immutable ESCROW;

    // ══════════════════════════════════════════════════════════════════════════════
    // Storage
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Provider reputation scores (0-1000)
    mapping(address provider => uint16 score) public scores;

    /// @notice Gains per provider per payer per epoch
    /// @dev provider => payer => epochStart => gains
    mapping(address => mapping(address => mapping(uint256 => uint16))) private _counterpartyGains;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Initialize registry with ESCROW address
     * @param _escrow AgentEscrow contract address (immutable)
     */
    constructor(address _escrow) {
        require(_escrow != address(0), "zero escrow");
        ESCROW = _escrow;
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
    // External Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IReputationRegistry
     * @dev Enforces INV-5: max 50 points per payer per epoch
     * @dev Clamps gain to remaining allowance, never silently skips
     * @dev Score saturates at MAX_SCORE (1000)
     */
    function recordSuccess(address provider, address payer, uint16 gain) external onlyEscrow {
        require(provider != address(0), "zero provider");
        require(payer != address(0), "zero payer");
        require(gain > 0, "zero gain");

        uint256 epochStart = getCurrentEpoch();
        uint16 currentScore = scores[provider];

        // Get current gains from this payer in this epoch
        uint16 existingGains = _counterpartyGains[provider][payer][epochStart];

        // Calculate remaining allowance for this counterparty (INV-5)
        uint16 remainingAllowance = MAX_COUNTERPARTY_GAIN_PER_EPOCH - existingGains;

        // Clamp gain to remaining allowance
        // If allowance exhausted, this will be 0 and we'll emit event but no score change
        uint16 actualGain = gain > remainingAllowance ? remainingAllowance : gain;

        // Update counterparty gains tracking
        _counterpartyGains[provider][payer][epochStart] = existingGains + actualGain;

        // Update score with saturation at MAX_SCORE
        uint16 newScore;
        unchecked {
            // Safe: actualGain <= 50, currentScore <= 1000, sum <= 1050
            uint256 sum = uint256(currentScore) + uint256(actualGain);
            // forge-lint: disable-next-line(unsafe-typecast)
            newScore = sum > MAX_SCORE ? MAX_SCORE : uint16(sum);
        }

        scores[provider] = newScore;

        // Emit event even if actualGain is 0 (cap hit) for transparency
        emit ReputationUpdated(
            provider,
            newScore,
            // forge-lint: disable-next-line(unsafe-typecast)
            int16(uint16(actualGain)), // Cast via uint16 to prevent overflow
            payer,
            epochStart
        );
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getScore(address provider) external view returns (uint16) {
        return scores[provider];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getCounterpartyGains(address provider, address payer) external view returns (uint16) {
        return _counterpartyGains[provider][payer][getCurrentEpoch()];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getCurrentEpoch() public view returns (uint256) {
        // forge-lint: disable-next-line(divide-before-multiply)
        return (block.timestamp / EPOCH_SECONDS) * EPOCH_SECONDS;
    }

    /**
     * @notice Get immutable escrow address
     */
    function escrow() external view returns (address) {
        return ESCROW;
    }
}
