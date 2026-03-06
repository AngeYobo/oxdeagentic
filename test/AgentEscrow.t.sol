// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {AgentEscrow} from "../src/AgentEscrow.sol";
import {IAgentEscrow} from "../src/interfaces/IAgentEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockStakeManager} from "./mocks/MockStakeManager.sol";
import {MockInsurancePool} from "./mocks/MockInsurancePool.sol";
import {MockReputationRegistry} from "./mocks/MockReputationRegistry.sol";

contract AgentEscrowTest is Test {
    AgentEscrow public escrow;
    MockERC20 public token;
    MockStakeManager public stakeManager;
    MockInsurancePool public insurancePool;
    MockReputationRegistry public reputationRegistry;

    address public arbiter = address(0xA);
    address public payer = address(0xB);
    address public provider = address(0xC);
    address public other = address(0xD);

    uint256 constant INITIAL_BALANCE = 10000 ether;

    // Intent parameters
    address testProvider = address(0xC);
    address testToken = address(0x1);
    uint96 testAmount = 100 ether;
    uint96 testBond = 10 ether;
    bytes32 testSalt = keccak256("salt");

    function setUp() public {
        // Deploy mocks
        token = new MockERC20("Test Token", "TEST", 18);
        stakeManager = new MockStakeManager();
        insurancePool = new MockInsurancePool();
        reputationRegistry = new MockReputationRegistry();

        // Deploy AgentEscrow
        escrow = new AgentEscrow(address(stakeManager), address(insurancePool), address(reputationRegistry), arbiter);

        // Setup balances
        token.mint(payer, INITIAL_BALANCE);
        token.mint(provider, INITIAL_BALANCE);

        // Approve escrow
        vm.prank(payer);
        token.approve(address(escrow), type(uint256).max);

        // Set max bond and payout
        vm.startPrank(arbiter);
        escrow.setMaxBondPerToken(address(token), 1000 ether);
        escrow.setMaxPayerPayoutPerToken(address(token), 100 ether);
        vm.stopPrank();

        // Warp to reasonable time
        vm.warp(100 days);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Helper Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function _createIntent(address _payer, address _token, uint96 _amount, bytes32 _commitHash)
        internal
        returns (bytes32 intentId)
    {
        deal(_token, _payer, _amount);

        vm.startPrank(_payer);
        MockERC20(_token).approve(address(escrow), type(uint256).max);
        intentId = escrow.createIntent(_token, _amount, _commitHash);
        vm.stopPrank();
    }

    function _createIntentDefault(bytes32 _commitHash) internal returns (bytes32 intentId) {
        return _createIntent(payer, address(token), 100 ether, _commitHash);
    }

    function _getCommitHash(address _provider, address _token, uint96 _amount, uint96 _bond, bytes32 _salt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_provider, _token, _amount, _bond, _salt));
    }

    function _createAndRevealIntent() internal returns (bytes32 intentId) {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor() public view {
        assertEq(escrow.stakeManager(), address(stakeManager));
        assertEq(escrow.insurancePool(), address(insurancePool));
        assertEq(escrow.reputationRegistry(), address(reputationRegistry));
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.REVEAL_DEADLINE(), 1 hours);
        assertEq(escrow.SETTLEMENT_DEADLINE(), 24 hours);
        assertEq(escrow.DISPUTE_DEADLINE(), 7 days);
        assertEq(escrow.FINALITY_GATE(), 3 days);
        assertEq(escrow.CREDIT_EXPIRY(), 30 days);
        assertEq(escrow.FASTMODE_THRESHOLD(), 800);
    }

    function test_Constructor_RevertZeroStakeManager() public {
        vm.expectRevert(IAgentEscrow.InvalidAddress.selector);
        new AgentEscrow(address(0), address(insurancePool), address(reputationRegistry), arbiter);
    }

    function test_Constructor_RevertZeroInsurancePool() public {
        vm.expectRevert(IAgentEscrow.InvalidAddress.selector);
        new AgentEscrow(address(stakeManager), address(0), address(reputationRegistry), arbiter);
    }

    function test_Constructor_RevertZeroReputation() public {
        vm.expectRevert(IAgentEscrow.InvalidAddress.selector);
        new AgentEscrow(address(stakeManager), address(insurancePool), address(0), arbiter);
    }

    function test_Constructor_RevertZeroArbiter() public {
        vm.expectRevert(IAgentEscrow.InvalidAddress.selector);
        new AgentEscrow(address(stakeManager), address(insurancePool), address(reputationRegistry), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // CreateIntent Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_CreateIntent() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertEq(intent.payer, payer);
        assertEq(intent.commitHash, commitHash);
        assertTrue(intent.state == IAgentEscrow.IntentState.COMMITTED);
        assertEq(escrow.firstSeen(payer), block.timestamp);
    }

    function test_CreateIntent_MultipleIntents() public {
        bytes32 hash1 = keccak256("hash1");
        bytes32 hash2 = keccak256("hash2");

        vm.startPrank(payer);
        bytes32 id1 = _createIntentDefault(hash1);
        bytes32 id2 = _createIntentDefault(hash2);
        vm.stopPrank();

        assertTrue(id1 != id2);
    }

    /*
    function test_CreateIntent_RevertAlreadyExists() public {
        bytes32 commitHash = keccak256("hash");

        vm.startPrank(payer);
        _createIntentDefault(commitHash);

        // Try to create again with same hash and timestamp
        vm.expectRevert(IAgentEscrow.IntentAlreadyExists.selector);
        _createIntentDefault(commitHash);
    }
    */

    // ══════════════════════════════════════════════════════════════════════════════
    // RevealIntent Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RevealIntent() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertEq(intent.commitHash, commitHash);
        assertEq(intent.provider, provider);
        assertEq(intent.token, address(token));
        assertEq(intent.amount, testAmount);
        assertEq(intent.bond, testBond);
        assertTrue(intent.state == IAgentEscrow.IntentState.REVEALED);
        assertFalse(intent.usedCredit);

        // Verify stake was locked
        assertTrue(stakeManager.wasLockCalled());
    }

    function test_RevealIntent_RevertNotPayer() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(other);
        vm.expectRevert(IAgentEscrow.OnlyPayer.selector);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
    }

    function test_RevealIntent_RevertWrongState() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        // Try to reveal again
        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
    }

    function test_RevealIntent_RevertDeadlineExpired() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        // Warp past reveal deadline
        vm.warp(block.timestamp + 2 hours);

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.RevealDeadlineExpired.selector);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
    }

    function test_RevealIntent_RevertInvalidHash() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        // Try to reveal with WRONG SALT (hash won't match)
        bytes32 wrongSalt = keccak256("wrong_salt");
        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.InvalidCommitHash.selector);
        escrow.revealIntent(intentId, provider, testBond, wrongSalt);
    }

    function test_RevealIntent_RevertBondExceedsAmount() public {
        uint96 invalidBond = testAmount + 1;
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, invalidBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.BondExceedsAmount.selector);
        escrow.revealIntent(intentId, provider, invalidBond, testSalt);
    }

    function test_RevealIntent_RevertBondExceedsMax() public {
        uint96 invalidBond = 2000 ether; // Over max of 1000 ether
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, invalidBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.BondExceedsMax.selector);
        escrow.revealIntent(intentId, provider, invalidBond, testSalt);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // SettleIntent Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_SettleIntent() public {
        bytes32 intentId = _createAndRevealIntent();

        uint256 payerBefore = token.balanceOf(payer);
        uint256 providerBefore = token.balanceOf(provider);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        uint16 successGain = 10;

        vm.prank(provider);
        escrow.settleIntent(intentId, successGain);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.state == IAgentEscrow.IntentState.SETTLED);

        assertTrue(stakeManager.wasUnlockCalled());
        assertTrue(reputationRegistry.wasRecordCalled());

        uint256 payerAfter = token.balanceOf(payer);
        uint256 providerAfter = token.balanceOf(provider);
        uint256 escrowAfter = token.balanceOf(address(escrow));

        // Custodial invariants:
        // - payer NOT debited at settle (already debited at createIntent)
        // - escrow pays provider at settle
        assertEq(payerAfter, payerBefore);
        assertEq(providerAfter, providerBefore + testAmount);
        assertEq(escrowAfter, escrowBefore - testAmount);
    }

    function test_SettleIntent_RevertNotProvider() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.OnlyProvider.selector);
        escrow.settleIntent(intentId, 10);
    }

    function test_SettleIntent_RevertWrongState() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        // Try to settle before reveal
        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.settleIntent(intentId, 10);
    }

    function test_SettleIntent_RevertDeadlineExpired() public {
        bytes32 intentId = _createAndRevealIntent();

        // Warp past settlement deadline
        vm.warp(block.timestamp + 25 hours);

        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.SettlementDeadlineExpired.selector);
        escrow.settleIntent(intentId, 10);
    }

    function test_SettleIntent_RevertZeroGain() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.ZeroAmount.selector);
        escrow.settleIntent(intentId, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // ExpireIntent Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExpireIntent() public {
        bytes32 intentId = _createAndRevealIntent();

        // Warp past dispute deadline
        vm.warp(block.timestamp + 8 days);

        escrow.expireIntent(intentId);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.state == IAgentEscrow.IntentState.EXPIRED);

        // Verify unlock was called
        assertTrue(stakeManager.wasUnlockCalled());
    }

    function test_ExpireIntent_RevertWrongState() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.expireIntent(intentId);
    }

    function test_ExpireIntent_RevertDeadlineNotExpired() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.expectRevert(IAgentEscrow.DisputeDeadlineNotExpired.selector);
        escrow.expireIntent(intentId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Dispute Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_InitiateDispute() public {
        bytes32 intentId = _createAndRevealIntent();

        string memory evidence = "Provider failed to deliver";

        vm.prank(payer);
        escrow.initiateDispute(intentId, evidence);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.state == IAgentEscrow.IntentState.DISPUTED);

        IAgentEscrow.Dispute memory dispute = escrow.getDispute(intentId);
        assertTrue(dispute.status == IAgentEscrow.DisputeStatus.ACTIVE);
    }

    function test_InitiateDispute_RevertNotPayer() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.OnlyPayer.selector);
        escrow.initiateDispute(intentId, "evidence");
    }

    function test_InitiateDispute_RevertWrongState() public {
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.initiateDispute(intentId, "evidence");
    }

    function test_InitiateDispute_RevertAlreadyExists() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.startPrank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.expectRevert(IAgentEscrow.DisputeAlreadyExists.selector);
        escrow.initiateDispute(intentId, "more evidence");
        vm.stopPrank();
    }

    function test_InitiateDispute_RevertDeadlineExpired() public {
        bytes32 intentId = _createAndRevealIntent();

        // Warp past dispute deadline
        vm.warp(block.timestamp + 8 days);

        vm.prank(payer);
        vm.expectRevert(IAgentEscrow.DisputeDeadlineExpired.selector);
        escrow.initiateDispute(intentId, "evidence");
    }

    function test_ResolveDispute_PayerWins() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        uint96 slashAmount = 5 ether;
        uint128 insuranceAmount = 50 ether;

        vm.prank(arbiter);
        escrow.resolveDispute(intentId, payer, slashAmount, insuranceAmount);

        IAgentEscrow.Dispute memory dispute = escrow.getDispute(intentId);
        assertTrue(dispute.status == IAgentEscrow.DisputeStatus.RESOLVED);
        assertEq(dispute.winner, payer);
        assertEq(dispute.slashAmount, slashAmount);

        // Verify slash was called
        assertTrue(stakeManager.wasSlashCalled());

        // Verify insurance claim was authorized
        assertTrue(insurancePool.wasAuthorizeCalled());

        // Verify unlock was called
        assertTrue(stakeManager.wasUnlockCalled());
    }

    function test_ResolveDispute_ProviderWins() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(arbiter);
        escrow.resolveDispute(intentId, provider, 0, 0);

        IAgentEscrow.Dispute memory dispute = escrow.getDispute(intentId);
        assertEq(dispute.winner, provider);

        // Verify unlock was called but not slash
        assertTrue(stakeManager.wasUnlockCalled());
        assertFalse(stakeManager.wasSlashCalled());
        assertFalse(insurancePool.wasAuthorizeCalled());
    }

    function test_ResolveDispute_RevertNotArbiter() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(other);
        vm.expectRevert(IAgentEscrow.OnlyArbiter.selector);
        escrow.resolveDispute(intentId, payer, 5 ether, 50 ether);
    }

    function test_ResolveDispute_RevertWrongState() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(arbiter);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.resolveDispute(intentId, payer, 5 ether, 50 ether);
    }

    function test_ResolveDispute_RevertInvalidWinner() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(arbiter);
        vm.expectRevert(IAgentEscrow.InvalidWinner.selector);
        escrow.resolveDispute(intentId, other, 5 ether, 50 ether);
    }

    function test_ResolveDispute_RevertSlashExceedsBond() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(arbiter);
        vm.expectRevert(IAgentEscrow.SlashExceedsBond.selector);
        escrow.resolveDispute(intentId, payer, testBond + 1, 50 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // FastMode Credit Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GrantCredit() public {
        // Set high reputation
        reputationRegistry.setScore(payer, 900);

        uint128 creditAmount = 100 ether;

        bytes32 creditId = escrow.grantCredit(payer, address(token), creditAmount);

        IAgentEscrow.FastCredit memory credit = escrow.getCredit(creditId);
        assertEq(credit.payer, payer);
        assertEq(credit.token, address(token));
        assertEq(credit.grantedAmount, creditAmount);
        assertEq(credit.remainingAmount, creditAmount);
        assertTrue(credit.status == IAgentEscrow.CreditStatus.ACTIVE);
    }

    function test_GrantCredit_RevertInsufficientReputation() public {
        // Low reputation
        reputationRegistry.setScore(payer, 500);

        vm.expectRevert(IAgentEscrow.InsufficientReputation.selector);
        escrow.grantCredit(payer, address(token), 100 ether);
    }

    function test_GrantCredit_RevertZeroAmount() public {
        reputationRegistry.setScore(payer, 900);

        vm.expectRevert(IAgentEscrow.ZeroAmount.selector);
        escrow.grantCredit(payer, address(token), 0);
    }

    function test_RevealIntent_WithCredit() public {
        // Grant credit first
        reputationRegistry.setScore(payer, 900);
        escrow.grantCredit(payer, address(token), 200 ether);

        // Create and reveal intent
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);

        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.usedCredit);

        // Verify lock was NOT called (using credit instead)
        assertFalse(stakeManager.wasLockCalled());
    }

    function test_ExpireCredit() public {
        reputationRegistry.setScore(payer, 900);
        bytes32 creditId = escrow.grantCredit(payer, address(token), 100 ether);

        // Warp past expiry
        vm.warp(block.timestamp + 31 days);

        escrow.expireCredit(creditId);

        IAgentEscrow.FastCredit memory credit = escrow.getCredit(creditId);
        assertTrue(credit.status == IAgentEscrow.CreditStatus.EXPIRED);
    }

    function test_ExpireCredit_RevertNotExpired() public {
        reputationRegistry.setScore(payer, 900);
        bytes32 creditId = escrow.grantCredit(payer, address(token), 100 ether);

        vm.expectRevert(IAgentEscrow.CreditNotExpired.selector);
        escrow.expireCredit(creditId);
    }

    function test_CanUseCredit() public {
        reputationRegistry.setScore(payer, 900);
        escrow.grantCredit(payer, address(token), 100 ether);

        assertTrue(escrow.canUseCredit(payer, address(token), 50 ether));
        assertFalse(escrow.canUseCredit(payer, address(token), 150 ether));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Integration Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FullLifecycle_Success() public {
        // 1. Create intent
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);
        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        // 2. Reveal intent
        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        // 3. Settle intent
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        // Verify final state
        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.state == IAgentEscrow.IntentState.SETTLED);
        assertEq(token.balanceOf(provider), INITIAL_BALANCE + testAmount);
    }

    function test_FullLifecycle_Dispute() public {
        // 1. Create and reveal
        bytes32 intentId = _createAndRevealIntent();

        // 2. Initiate dispute
        vm.prank(payer);
        escrow.initiateDispute(intentId, "Provider failed");

        // 3. Resolve dispute (payer wins)
        vm.prank(arbiter);
        escrow.resolveDispute(intentId, payer, 5 ether, 50 ether);

        // Verify dispute resolved
        IAgentEscrow.Dispute memory dispute = escrow.getDispute(intentId);
        assertTrue(dispute.status == IAgentEscrow.DisputeStatus.RESOLVED);
    }

    function test_FullLifecycle_WithCredit() public {
        // 1. Grant credit
        reputationRegistry.setScore(payer, 900);
        escrow.grantCredit(payer, address(token), 200 ether);

        // 2. Create and reveal (uses credit)
        bytes32 commitHash = _getCommitHash(provider, address(token), testAmount, testBond, testSalt);
        vm.prank(payer);
        bytes32 intentId = _createIntentDefault(commitHash);

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        // 3. Settle
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        // Verify used credit
        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertTrue(intent.usedCredit);
    }

    function test_Debug_MaxBondIsSet() public view {
        assertEq(escrow.MAX_BOND_PER_TOKEN(address(token)), 1000 ether);
    }

    // ❌ MANQUANT: Settlement après révocation allowance (devrait passer)
    function test_Security_SettleAfterAllowanceRevoked() public {
        bytes32 intentId = _createAndRevealIntent();

        // Payer révoque son allowance (malveillant ou accident)
        vm.prank(payer);
        token.approve(address(escrow), 0);

        // Settlement devrait ENCORE fonctionner (fonds en custody)
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        // Vérifier que provider a reçu les fonds
        assertEq(token.balanceOf(provider), INITIAL_BALANCE + testAmount);
    }

    // ❌ MANQUANT: Vérifier custody à chaque étape
    function test_Security_CustodialInvariants() public {
        // Setup initial balances AVANT create
        deal(address(token), payer, INITIAL_BALANCE);
        deal(address(token), provider, INITIAL_BALANCE);

        vm.prank(payer);
        token.approve(address(escrow), type(uint256).max);

        uint256 payerBefore = token.balanceOf(payer);
        uint256 escrowBefore = token.balanceOf(address(escrow));


        // 1. Create: payer débité, escrow crédité
        bytes32 commitHash = keccak256(abi.encodePacked(provider, address(token), testAmount, testBond, testSalt));

        vm.startPrank(payer);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);
        vm.stopPrank();

        assertEq(token.balanceOf(payer), payerBefore - testAmount);
        assertEq(token.balanceOf(address(escrow)), escrowBefore + testAmount);

        // 2. Reveal: aucun transfert
        uint256 payerAfterReveal = token.balanceOf(payer);
        uint256 escrowAfterReveal = token.balanceOf(address(escrow));

        vm.prank(payer);
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        assertEq(token.balanceOf(payer), payerAfterReveal);
        assertEq(token.balanceOf(address(escrow)), escrowAfterReveal);

        // 3. Settle: escrow débité, provider crédité
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        assertEq(token.balanceOf(address(escrow)), escrowAfterReveal - testAmount);
        assertEq(token.balanceOf(provider), INITIAL_BALANCE + testAmount);
    }

    // ❌ MANQUANT: Impossibilité de double settle
    function test_Security_CannotDoubleSettle() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        // Try to settle again
        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.settleIntent(intentId, 10);
    }

    function test_Security_RevealInvalidHash_WrongBond() public {
        uint96 correctBond = 10 ether;
        uint96 wrongBond = 20 ether;

        // Create with bond=10
        bytes32 commitHash = keccak256(abi.encodePacked(provider, address(token), testAmount, correctBond, testSalt));

        vm.startPrank(payer);
        deal(address(token), payer, testAmount);
        token.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);

        // Try to reveal with bond=20 - should revert
        vm.expectRevert(IAgentEscrow.InvalidCommitHash.selector);
        escrow.revealIntent(intentId, provider, wrongBond, testSalt);
        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Security: Immutability Tests
    // ══════════════════════════════════════════════════════════════════════════════

    /// @dev Verify token and amount are immutable after creation (custodial model)
    function test_Security_TokenAmountImmutable() public {

        bytes32 commitHash = keccak256(abi.encodePacked(provider, address(token), testAmount, testBond, testSalt));

        vm.startPrank(payer);
        deal(address(token), payer, testAmount);
        token.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);

        // Capture initial values
        IAgentEscrow.Intent memory intentBefore = escrow.getIntent(intentId);
        address tokenBefore = intentBefore.token;
        uint96 amountBefore = intentBefore.amount;

        // Reveal should NOT modify token or amount
        escrow.revealIntent(intentId, provider, testBond, testSalt);

        // Verify token and amount remain unchanged
        IAgentEscrow.Intent memory intentAfter = escrow.getIntent(intentId);
        assertEq(intentAfter.token, tokenBefore, "Token should be immutable");
        assertEq(intentAfter.amount, amountBefore, "Amount should be immutable");

        // Additional verification: values match creation parameters
        assertEq(intentAfter.token, address(token), "Token should match creation");
        assertEq(intentAfter.amount, testAmount, "Amount should match creation");

        vm.stopPrank();
    }

    function test_Economic_ExpireIntent_ShouldRefundPayer() public {
        // Arrange: create + reveal
        bytes32 intentId = _createAndRevealIntent();

        uint256 payerBefore = token.balanceOf(payer);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        // Warp past dispute deadline (needed to expire)
        vm.warp(block.timestamp + 8 days);

        // Act
        escrow.expireIntent(intentId);

        // Assert: refund principal to payer
        uint256 payerAfter = token.balanceOf(payer);
        uint256 escrowAfter = token.balanceOf(address(escrow));

        assertEq(payerAfter, payerBefore + testAmount, "payer should be refunded on EXPIRED");
        assertEq(escrowAfter, escrowBefore - testAmount, "escrow should decrease by amount on EXPIRED");
    }

    function test_Economic_DisputePayerWins_ShouldRefundPayer() public {
        bytes32 intentId = _createAndRevealIntent();

        // Move to DISPUTED
        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        uint256 payerBefore = token.balanceOf(payer);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        // Resolve: payer wins (slash/insurance can be 0 for pure economic test)
        vm.prank(arbiter);
        escrow.resolveDispute(intentId, payer, 0, 0);

        uint256 payerAfter = token.balanceOf(payer);
        uint256 escrowAfter = token.balanceOf(address(escrow));

        assertEq(payerAfter, payerBefore + testAmount, "payer should be refunded when payer wins dispute");
        assertEq(escrowAfter, escrowBefore - testAmount, "escrow should decrease by amount when payer wins dispute");
    }

    function test_Economic_DisputeProviderWins_ShouldPayProvider() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        uint256 providerBefore = token.balanceOf(provider);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        vm.prank(arbiter);
        escrow.resolveDispute(intentId, provider, 0, 0);

        uint256 providerAfter = token.balanceOf(provider);
        uint256 escrowAfter = token.balanceOf(address(escrow));

        assertEq(providerAfter, providerBefore + testAmount, "provider should be paid when provider wins dispute");
        assertEq(escrowAfter, escrowBefore - testAmount, "escrow should decrease by amount when provider wins dispute");
    }

    function test_Economic_TerminalState_ShouldNotLeaveFundsInEscrow() public {
        bytes32 intentId = _createAndRevealIntent();

        // Case: expire path
        vm.warp(block.timestamp + 8 days);
        escrow.expireIntent(intentId);

        // At this point, escrow should NOT still hold amount attributable to this intent.
        // Simplest check: escrow balance should be 0 if this test only created one intent.
        assertEq(token.balanceOf(address(escrow)), 0, "escrow should not retain funds after EXPIRED");
    }

    function test_Economic_ExpireIntent_CannotDoubleRefund() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.warp(block.timestamp + 8 days);
        escrow.expireIntent(intentId);

        // Second call should revert due to state != REVEALED
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.expireIntent(intentId);
    }

    function test_Economic_ResolveDispute_CannotDoublePayout() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(arbiter);
        escrow.resolveDispute(intentId, payer, 0, 0);

        // Second resolve should revert:
        // - intent no longer DISPUTED (now RESOLVED)
        vm.prank(arbiter);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.resolveDispute(intentId, payer, 0, 0);
    }

    function test_Economic_ResolvedDispute_CannotExpire() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(payer);
        escrow.initiateDispute(intentId, "evidence");

        vm.prank(arbiter);
        escrow.resolveDispute(intentId, payer, 0, 0);

        vm.warp(block.timestamp + 8 days);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.expireIntent(intentId);
    }

    function test_Economic_ExpireIntent_EscrowDecreasesByAmount() public {
        bytes32 intentId = _createAndRevealIntent();

        uint256 escrowBefore = token.balanceOf(address(escrow));
        vm.warp(block.timestamp + 8 days);
        escrow.expireIntent(intentId);
        uint256 escrowAfter = token.balanceOf(address(escrow));

        assertEq(escrowAfter, escrowBefore - testAmount);
    }

    function test_Economic_PrincipalPaid_SafetyNet() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        vm.warp(block.timestamp + 8 days);

        // Un intent SETTLED ne peut pas expirer
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.expireIntent(intentId);
    }

    function test_Economic_SettleIntent_PrincipalAlreadyPaid() public {
        bytes32 intentId = _createAndRevealIntent();

        vm.prank(provider);
        escrow.settleIntent(intentId, 10);

        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.settleIntent(intentId, 10);
    }
}
