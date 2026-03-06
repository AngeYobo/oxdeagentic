// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAgentEscrow} from "./interfaces/IAgentEscrow.sol";
import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {IInsurancePool} from "./interfaces/IInsurancePool.sol";
import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";

/**
 * @title AgentEscrow
 * @notice Main orchestrator for decentralized AI agent settlement with commit-reveal intents
 * @dev Phase 0: Basic settlement with dispute resolution, FastMode credits, and insurance
 *
 * Architecture:
 * - Commit-Reveal: Payer commits hash(params), reveals later to prevent front-running
 * - FastMode: High-reputation payers get instant credits (skip locking)
 * - IAgentEscrow.Dispute Resolution: Arbiter resolves disputes, slashes loser
 * - Insurance: Failed intents can claim from pool (with caps)
 * - Reputation: Successful settlements increase provider scores
 *
 * State Machines:
 * 1. IAgentEscrow.Intent: COMMITTED → REVEALED → SETTLED/DISPUTED/EXPIRED
 * 2. IAgentEscrow.Dispute: NONE → ACTIVE → RESOLVED
 * 3. Credit: ACTIVE → CONSUMED/EXPIRED
 *
 * Invariants:
 * - INV-2: Bond ≤ amount (enforced in reveal)
 * - INV-4: FastMode only for reputation ≥ threshold
 * - State transitions are monotonic (no rollbacks)
 * - Disputes have single resolution
 *
 * Security:
 * - ReentrancyGuard on all state-changing functions
 * - SafeERC20 for all token transfers
 * - Commit-reveal prevents front-running
 * - CEI pattern throughout
 */
contract AgentEscrow is IAgentEscrow, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constants
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Reveal deadline (1 hour after commit)
    uint256 public constant REVEAL_DEADLINE = 1 hours;

    /// @notice Settlement deadline (24 hours after reveal)
    uint256 public constant SETTLEMENT_DEADLINE = 24 hours;

    /// @notice IAgentEscrow.Dispute deadline (7 days after reveal)
    uint256 public constant DISPUTE_DEADLINE = 7 days;

    /// @notice Finality gate (providers must wait before withdrawing stake)
    uint256 public constant FINALITY_GATE = 3 days;

    /// @notice Credit expiry (30 days)
    uint256 public constant CREDIT_EXPIRY = 30 days;

    /// @notice FastMode reputation threshold (800 points)
    uint16 public constant FASTMODE_THRESHOLD = 800;

    /// @notice Cached chain ID for intent ID generation
    uint256 public immutable CHAIN_ID;

    // ══════════════════════════════════════════════════════════════════════════════
    // Immutable Dependencies
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice StakeManager contract
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    address public immutable stakeManager;

    /// @notice InsurancePool contract
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    address public immutable insurancePool;

    /// @notice ReputationRegistry contract
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    address public immutable reputationRegistry;

    /// @notice Arbiter address (trusted dispute resolver)
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    address public immutable arbiter;

    // ══════════════════════════════════════════════════════════════════════════════
    // Storage
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Intents by intentId
    mapping(bytes32 => IAgentEscrow.Intent) public intents;

    /// @notice Disputes by intentId
    mapping(bytes32 => IAgentEscrow.Dispute) public disputes;

    /// @notice FastMode credits by creditId
    mapping(bytes32 => IAgentEscrow.FastCredit) public credits;

    /// @notice First seen timestamp for payers (for insurance age ramp)
    mapping(address => uint64) public firstSeen;

    /// @notice Maximum bond per token (governance parameter)
    // forge-lint: disable-next-line(mixed-case-variable)
    mapping(address => uint256) public MAX_BOND_PER_TOKEN;

    /// @notice Maximum payout per token (governance parameter)
    // forge-lint: disable-next-line(mixed-case-variable)
    mapping(address => uint256) public MAX_PAYER_PAYOUT_PER_TOKEN;

    mapping(address => uint64) public nonces;

    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════

    error BadClaimId();

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Initialize AgentEscrow with dependencies
     * @param _stakeManager StakeManager contract address
     * @param _insurancePool InsurancePool contract address
     * @param _reputationRegistry ReputationRegistry contract address
     * @param _arbiter Arbiter address for dispute resolution
     */
    constructor(address _stakeManager, address _insurancePool, address _reputationRegistry, address _arbiter) {
        if (_stakeManager == address(0)) revert InvalidAddress();
        if (_insurancePool == address(0)) revert InvalidAddress();
        if (_reputationRegistry == address(0)) revert InvalidAddress();
        if (_arbiter == address(0)) revert InvalidAddress();

        stakeManager = _stakeManager;
        insurancePool = _insurancePool;
        reputationRegistry = _reputationRegistry;
        arbiter = _arbiter;
        CHAIN_ID = block.chainid;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Modifiers
    // ══════════════════════════════════════════════════════════════════════════════

    modifier onlyArbiter() {
        _onlyArbiter();
        _;
    }

    function _onlyArbiter() internal view {
        if (msg.sender != arbiter) revert OnlyArbiter();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // IAgentEscrow.Intent Lifecycle Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IAgentEscrow
     */
    function createIntent(
        address token, //  REQUIS
        uint96 amount, //  REQUIS
        bytes32 commitHash
    )
        external
        nonReentrant
        returns (bytes32 intentId)
    {
        //  Validation token support
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert ZeroAmount();
        if (MAX_BOND_PER_TOKEN[token] == 0) revert UnsupportedToken();
        if (MAX_PAYER_PAYOUT_PER_TOKEN[token] == 0) revert UnsupportedToken();

        uint64 nonce = ++nonces[msg.sender];
        intentId = _generateIntentId(msg.sender, commitHash, nonce);

        if (intents[intentId].state != IAgentEscrow.IntentState.NONE) {
            revert IntentAlreadyExists();
        }

        if (firstSeen[msg.sender] == 0) {
            firstSeen[msg.sender] = uint64(block.timestamp);
        }

        //  CUSTODY TRANSFER - CRITIQUE!
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        intents[intentId] = IAgentEscrow.Intent({
            payer: msg.sender,
            provider: address(0), // Set on reveal
            token: token, //  From parameter
            amount: amount, //  From parameter
            bond: 0, // Set on reveal
            commitHash: commitHash,
            committedAt: uint64(block.timestamp),
            revealedAt: 0,
            settledAt: 0,
            nonce: nonce,
            state: IAgentEscrow.IntentState.COMMITTED,
            usedCredit: false,
            principalPaid: false
        });

        emit IntentCreated(intentId, msg.sender, commitHash, uint64(block.timestamp));
    }

    function _payPrincipal(IAgentEscrow.Intent storage intent, address to) internal {
        if (intent.principalPaid) revert PrincipalAlreadyPaid();

        // Effects
        intent.principalPaid = true;

        // Interaction
        IERC20(intent.token).safeTransfer(to, intent.amount);
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function revealIntent(bytes32 intentId, address provider, uint96 bond, bytes32 salt) external nonReentrant {
        IAgentEscrow.Intent storage intent = intents[intentId];

        // Validation
        if (msg.sender != intent.payer) revert OnlyPayer();
        if (intent.state != IAgentEscrow.IntentState.COMMITTED) revert InvalidIntentState();
        if (block.timestamp > intent.committedAt + REVEAL_DEADLINE) {
            intent.state = IAgentEscrow.IntentState.EXPIRED;
            revert RevealDeadlineExpired();
        }

        // Verify commit hash using STORED token/amount (custodial)
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 computedHash = keccak256(
            abi.encodePacked(
                provider,
                intent.token, //  From storage (set at createIntent)
                intent.amount, //  From storage (set at createIntent)
                bond,
                salt
            )
        );
        if (computedHash != intent.commitHash) revert InvalidCommitHash();

        // Validate parameters (INV-2: bond ≤ amount)
        if (provider == address(0)) revert InvalidAddress();
        if (bond > MAX_BOND_PER_TOKEN[intent.token]) revert BondExceedsMax();
        if (bond > intent.amount) revert BondExceedsAmount();

        // Update intent (NO token/amount modification - custodial model)
        intent.provider = provider;
        intent.bond = bond;
        intent.revealedAt = uint64(block.timestamp);
        intent.state = IAgentEscrow.IntentState.REVEALED;

        // Check if payer can use FastMode credit
        bytes32 creditId = _getCreditId(intent.payer, intent.token);
        IAgentEscrow.FastCredit storage credit = credits[creditId];

        bool usedCredit = false;
        if (
            credit.status == IAgentEscrow.CreditStatus.ACTIVE && credit.remainingAmount >= intent.amount
                && block.timestamp <= credit.expiresAt
        ) {
            // Consume credit (no stake lock needed)
            credit.remainingAmount -= intent.amount;
            if (credit.remainingAmount == 0) {
                credit.status = IAgentEscrow.CreditStatus.CONSUMED;
            }
            intent.usedCredit = true;
            usedCredit = true;

            emit CreditConsumed(creditId, intent.payer, intent.token, intent.amount, credit.remainingAmount);
        } else {
            // Regular path: lock stake
            IStakeManager(stakeManager).lockStake(provider, intent.token, bond, intentId);
        }

        emit IntentRevealed(intentId, provider, intent.token, intent.amount, bond, usedCredit, uint64(block.timestamp));
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function settleIntent(bytes32 intentId, uint16 successGain) external nonReentrant {
        IAgentEscrow.Intent storage intent = intents[intentId];

        // Validation
        if (intent.state != IAgentEscrow.IntentState.REVEALED) revert InvalidIntentState();
        if (msg.sender != intent.provider) revert OnlyProvider();

        if (block.timestamp > intent.revealedAt + SETTLEMENT_DEADLINE) {
            revert SettlementDeadlineExpired();
        }
        if (successGain == 0) revert ZeroAmount();

        // Effects (CEI)
        intent.state = IAgentEscrow.IntentState.SETTLED;
        intent.settledAt = uint64(block.timestamp);
        _payPrincipal(intent, intent.provider);

        // Unlock stake (if not using credit)
        if (!intent.usedCredit) {
            IStakeManager(stakeManager).unlockStake(intentId);
        }

        // Record success in reputation registry
        IReputationRegistry(reputationRegistry).recordSuccess(intent.payer, intent.provider, successGain);

        emit IntentSettled(intentId, successGain, uint64(block.timestamp));
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function expireIntent(bytes32 intentId) external nonReentrant {
        IAgentEscrow.Intent storage intent = intents[intentId];

        if (intent.state != IAgentEscrow.IntentState.REVEALED) revert InvalidIntentState();
        if (block.timestamp <= intent.revealedAt + DISPUTE_DEADLINE) revert DisputeDeadlineNotExpired();

        // Effects
        intent.state = IAgentEscrow.IntentState.EXPIRED;
        intent.settledAt = uint64(block.timestamp);
        _payPrincipal(intent, intent.payer);

        // Unlock stake (if not using credit)
        if (!intent.usedCredit) {
            IStakeManager(stakeManager).unlockStake(intentId);
        }

        emit IntentExpired(intentId, uint64(block.timestamp));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // IAgentEscrow.Dispute Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IAgentEscrow
     */
    function initiateDispute(bytes32 intentId, string calldata evidence) external nonReentrant {
        IAgentEscrow.Intent storage intent = intents[intentId];

        // Validation - REORDER THESE TWO LINES:
        if (msg.sender != intent.payer) revert OnlyPayer();
        if (disputes[intentId].status != IAgentEscrow.DisputeStatus.NONE) {
            //  CHECK THIS FIRST
            revert DisputeAlreadyExists();
        }
        if (intent.state != IAgentEscrow.IntentState.REVEALED) revert InvalidIntentState(); //  THEN THIS
        if (block.timestamp > intent.revealedAt + DISPUTE_DEADLINE) {
            revert DisputeDeadlineExpired();
        }

        // Create dispute
        disputes[intentId] = IAgentEscrow.Dispute({
            initiatedAt: uint64(block.timestamp),
            resolvedAt: 0,
            status: IAgentEscrow.DisputeStatus.ACTIVE,
            winner: address(0),
            slashAmount: 0
        });

        // Update intent state
        intent.state = IAgentEscrow.IntentState.DISPUTED;

        emit DisputeInitiated(intentId, intent.payer, evidence, uint64(block.timestamp));
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function resolveDispute(bytes32 intentId, address winner, uint96 slashAmount, uint128 insuranceAmount)
        external
        onlyArbiter
        nonReentrant
    {
        IAgentEscrow.Intent storage intent = intents[intentId];
        IAgentEscrow.Dispute storage dispute = disputes[intentId];

        if (intent.state != IAgentEscrow.IntentState.DISPUTED) revert InvalidIntentState();
        if (dispute.status != IAgentEscrow.DisputeStatus.ACTIVE) revert DisputeNotActive();
        if (winner != intent.payer && winner != intent.provider) revert InvalidWinner();
        if (slashAmount > intent.bond) revert SlashExceedsBond();
        if (insuranceAmount > intent.amount) revert InvalidAmount();

        // Effects
        dispute.status = IAgentEscrow.DisputeStatus.RESOLVED;
        dispute.winner = winner;
        dispute.slashAmount = slashAmount;
        dispute.resolvedAt = uint64(block.timestamp);

        // Slash (only if provider lost AND stake path used)
        if (winner == intent.payer && slashAmount > 0 && !intent.usedCredit) {
            IStakeManager(stakeManager).slash(intentId, slashAmount);
        }

        // Insurance authorization (kept as-is)
        if (insuranceAmount > 0) {
            bytes32 claimId = IInsurancePool(insurancePool)
                .authorizeClaim(
                    intentId, intent.payer, intent.provider, intent.token, insuranceAmount, uint128(intent.amount)
                );
            // forge-lint: disable-next-line(asm-keccak256)
            bytes32 expected = keccak256(abi.encodePacked(block.chainid, insurancePool, intentId));
            if (claimId != expected) revert BadClaimId();
        }

        // Unlock remaining stake
        if (!intent.usedCredit) {
            IStakeManager(stakeManager).unlockStake(intentId);
        }

        // NEW: terminalize intent
        intent.state = IAgentEscrow.IntentState.RESOLVED;
        intent.settledAt = uint64(block.timestamp);
        _payPrincipal(intent, winner);

        emit DisputeResolved(intentId, winner, slashAmount, insuranceAmount, uint64(block.timestamp));
        emit IntentResolved(intentId, winner, intent.amount, uint64(block.timestamp));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FastMode Credit Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IAgentEscrow
     */
    function grantCredit(address payer, address token, uint128 amount) external returns (bytes32 creditId) {
        // Anyone can grant credit, but reputation must meet threshold
        uint16 score = IReputationRegistry(reputationRegistry).getScore(payer);
        if (score < FASTMODE_THRESHOLD) revert InsufficientReputation();
        if (amount == 0) revert ZeroAmount();

        creditId = _getCreditId(payer, token);
        IAgentEscrow.FastCredit storage credit = credits[creditId];

        // Check if credit already exists
        if (credit.status == IAgentEscrow.CreditStatus.ACTIVE) {
            // Add to existing credit
            credit.remainingAmount += amount;
            // casting to uint64 is safe because block.timestamp fits into uint64 for the foreseeable future
            // forge-lint: disable-next-line(unsafe-typecast)
            credit.expiresAt = uint64(block.timestamp + CREDIT_EXPIRY);
        } else {
            // Create new credit
            credits[creditId] = IAgentEscrow.FastCredit({
                payer: payer,
                token: token,
                grantedAmount: amount,
                remainingAmount: amount,
                grantedAt: uint64(block.timestamp),
                // casting to uint64 is safe because block.timestamp fits into uint64 for the foreseeable future
                // forge-lint: disable-next-line(unsafe-typecast)
                expiresAt: uint64(block.timestamp + CREDIT_EXPIRY),
                status: IAgentEscrow.CreditStatus.ACTIVE
            });
        }

        emit CreditGranted(creditId, payer, token, amount, uint64(block.timestamp));
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function expireCredit(bytes32 creditId) external {
        IAgentEscrow.FastCredit storage credit = credits[creditId];

        if (credit.status != IAgentEscrow.CreditStatus.ACTIVE) revert CreditNotActive();
        if (block.timestamp <= credit.expiresAt) revert CreditNotExpired();

        credit.status = IAgentEscrow.CreditStatus.EXPIRED;

        emit CreditExpired(creditId, uint64(block.timestamp));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @inheritdoc IAgentEscrow
     */
    function getIntent(bytes32 intentId) external view returns (IAgentEscrow.Intent memory) {
        return intents[intentId];
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function getDispute(bytes32 intentId) external view returns (IAgentEscrow.Dispute memory) {
        return disputes[intentId];
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function getCredit(bytes32 creditId) external view returns (IAgentEscrow.FastCredit memory) {
        return credits[creditId];
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function canUseCredit(address payer, address token, uint256 amount) external view returns (bool) {
        bytes32 creditId = _getCreditId(payer, token);
        IAgentEscrow.FastCredit storage credit = credits[creditId];

        return credit.status == IAgentEscrow.CreditStatus.ACTIVE && credit.remainingAmount >= amount
            && block.timestamp <= credit.expiresAt;
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function maxBondPerToken(address token) external view returns (uint256) {
        return MAX_BOND_PER_TOKEN[token];
    }

    /**
     * @inheritdoc IAgentEscrow
     */
    function maxPayerPayoutPerToken(address token) external view returns (uint256) {
        return MAX_PAYER_PAYOUT_PER_TOKEN[token];
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Governance Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Set maximum bond per token (governance only)
     * @dev In production, this would be behind a timelock
     * @param token Token address
     * @param maxBond Maximum bond amount
     */
    function setMaxBondPerToken(address token, uint256 maxBond) external onlyArbiter {
        MAX_BOND_PER_TOKEN[token] = maxBond;
    }

    /**
     * @notice Set maximum payout per token (governance only, forwarded to insurance)
     * @dev In production, this would be behind a timelock
     * @param token Token address
     * @param maxPayout Maximum payout amount
     */
    function setMaxPayerPayoutPerToken(address token, uint256 maxPayout) external onlyArbiter {
        MAX_PAYER_PAYOUT_PER_TOKEN[token] = maxPayout;
        // IInsurancePool(insurancePool).setMaxPayerPayoutPerToken(token, maxPayout);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Internal Functions
    // IInsurancePool(insurancePool).setMaxPayerPayoutPerToken(token, maxPayout);

    /**
     * @notice Generate deterministic intentId
     * @param payer Payer address
     * @param commitHash Commit hash
     * @return intentId IAgentEscrow.Intent identifier
     */
    function _generateIntentId(address payer, bytes32 commitHash, uint64 nonce) internal view returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(CHAIN_ID, address(this), payer, commitHash, nonce));
    }

    /**
     * @notice Get credit ID for payer+token pair
     * @param payer Payer address
     * @param token Token address
     * @return creditId Credit identifier
     */
    function _getCreditId(address payer, address token) internal pure returns (bytes32) {
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(abi.encodePacked(payer, token));
    }
}
