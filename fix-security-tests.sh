#!/bin/bash
set -e

echo "🔧 Correction des tests de sécurité..."

# Backup
cp test/AgentEscrowSecurity.t.sol test/AgentEscrow.t.sol.backup-fix

# Créer version corrigée
cat > test/AgentEscrowSecurity.t.sol << 'SOLIDITY'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {AgentEscrow} from "../src/AgentEscrow.sol";
import {IAgentEscrow} from "../src/interfaces/IAgentEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockStakeManager} from "./mocks/MockStakeManager.sol";
import {MockInsurancePool} from "./mocks/MockInsurancePool.sol";
import {MockReputationRegistry} from "./mocks/MockReputationRegistry.sol";

/**
 * @title AgentEscrowTest
 * @notice Tests critiques de sécurité
 */
contract AgentEscrowTest is Test {
    AgentEscrow public escrow;
    MockERC20 public token;
    MockStakeManager public stakeManager;
    MockInsurancePool public insurancePool;
    MockReputationRegistry public reputationRegistry;
    
    address public arbiter = address(0xA);
    address public payer = address(0xB);
    address public provider = address(0xC);
    
    uint256 constant INITIAL_BALANCE = 10000 ether;
    
    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        stakeManager = new MockStakeManager();
        insurancePool = new MockInsurancePool();
        reputationRegistry = new MockReputationRegistry();
        
        escrow = new AgentEscrow(
            address(stakeManager),
            address(insurancePool),
            address(reputationRegistry),
            arbiter
        );
        
        vm.startPrank(arbiter);
        escrow.setMaxBondPerToken(address(token), 1000 ether);
        escrow.setMaxPayerPayoutPerToken(address(token), 100 ether);
        vm.stopPrank();
        
        vm.warp(100 days);
    }
    
    /// @dev Custodial: Full lifecycle invariants
    function test_Security_CustodialInvariants() public {
        // Setup balances
        deal(address(token), payer, INITIAL_BALANCE);
        deal(address(token), provider, INITIAL_BALANCE);
        
        vm.prank(payer);
        token.approve(address(escrow), type(uint256).max);
        
        uint256 payerBefore = token.balanceOf(payer);
        uint256 escrowBefore = token.balanceOf(address(escrow));
        
        uint96 testAmount = 100 ether;
        uint96 testBond = 10 ether;
        bytes32 testSalt = keccak256("salt");
        
        // 1. Create: payer débité, escrow crédité
        bytes32 commitHash = keccak256(abi.encodePacked(
            provider, address(token), testAmount, testBond, testSalt
        ));
        
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
    
    /// @dev Cannot settle twice (state protection)
    function test_Security_CannotDoubleSettle() public {
        uint96 testAmount = 100 ether;
        uint96 testBond = 10 ether;
        bytes32 testSalt = keccak256("salt");
        
        bytes32 commitHash = keccak256(abi.encodePacked(
            provider, address(token), testAmount, testBond, testSalt
        ));
        
        vm.startPrank(payer);
        deal(address(token), payer, testAmount);
        token.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
        vm.stopPrank();
        
        // First settle
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);
        
        // Try to settle again
        vm.prank(provider);
        vm.expectRevert(IAgentEscrow.InvalidIntentState.selector);
        escrow.settleIntent(intentId, 10);
    }
    
    /// @dev Token is immutable after creation
    function test_Security_TokenImmutableAfterCreate() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        
        vm.startPrank(arbiter);
        escrow.setMaxBondPerToken(address(usdc), 1000 ether);
        escrow.setMaxPayerPayoutPerToken(address(usdc), 100 ether);
        vm.stopPrank();
        
        uint96 testAmount = 100 ether;
        uint96 testBond = 10 ether;
        bytes32 testSalt = keccak256("salt");
        
        // Create with USDC
        bytes32 commitHash = keccak256(abi.encodePacked(
            provider, address(usdc), testAmount, testBond, testSalt
        ));
        
        vm.startPrank(payer);
        deal(address(usdc), payer, testAmount);
        usdc.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(usdc), testAmount, commitHash);
        
        // Verify intent stores USDC
        IAgentEscrow.Intent memory intent = escrow.getIntent(intentId);
        assertEq(intent.token, address(usdc));
        assertEq(intent.amount, testAmount);
        
        vm.stopPrank();
    }
    
    /// @dev Reveal with wrong bond fails hash verification
    function test_Security_RevealWrongBond() public {
        uint96 testAmount = 100 ether;
        uint96 correctBond = 10 ether;
        uint96 wrongBond = 20 ether;
        bytes32 testSalt = keccak256("salt");
        
        // Create with bond=10
        bytes32 commitHash = keccak256(abi.encodePacked(
            provider, address(token), testAmount, correctBond, testSalt
        ));
        
        vm.startPrank(payer);
        deal(address(token), payer, testAmount);
        token.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);
        
        // Try to reveal with bond=20 - should revert
        vm.expectRevert(IAgentEscrow.InvalidCommitHash.selector);
        escrow.revealIntent(intentId, provider, wrongBond, testSalt);
        vm.stopPrank();
    }
    
    /// @dev Settlement works without allowance (custodial model)
    function test_Security_SettleWithoutAllowance() public {
        uint96 testAmount = 100 ether;
        uint96 testBond = 10 ether;
        bytes32 testSalt = keccak256("salt");
        
        bytes32 commitHash = keccak256(abi.encodePacked(
            provider, address(token), testAmount, testBond, testSalt
        ));
        
        vm.startPrank(payer);
        deal(address(token), payer, testAmount);
        token.approve(address(escrow), type(uint256).max);
        bytes32 intentId = escrow.createIntent(address(token), testAmount, commitHash);
        escrow.revealIntent(intentId, provider, testBond, testSalt);
        
        // Payer revokes allowance (malicious or accident)
        token.approve(address(escrow), 0);
        vm.stopPrank();
        
        // Settlement should STILL work (funds in custody)
        vm.prank(provider);
        escrow.settleIntent(intentId, 10);
        
        // Verify provider received funds
        assertTrue(token.balanceOf(provider) >= testAmount);
    }
    
    /// @dev Multiple tokens isolation
    function test_Security_MultipleTokensIsolation() public {
        MockERC20 usdc = new MockERC20("USDC", "USDC", 6);
        MockERC20 dai = new MockERC20("DAI", "DAI", 18);
        
        vm.startPrank(arbiter);
        escrow.setMaxBondPerToken(address(usdc), 1000e6);
        escrow.setMaxPayerPayoutPerToken(address(usdc), 100e6);
        escrow.setMaxBondPerToken(address(dai), 1000 ether);
        escrow.setMaxPayerPayoutPerToken(address(dai), 100 ether);
        vm.stopPrank();
        
        bytes32 saltUSDC = keccak256("usdc");
        bytes32 saltDAI = keccak256("dai");
        
        // Create intent with USDC
        bytes32 hashUSDC = keccak256(abi.encodePacked(
            provider, address(usdc), uint96(100e6), uint96(10e6), saltUSDC
        ));
        
        vm.startPrank(payer);
        deal(address(usdc), payer, 100e6);
        usdc.approve(address(escrow), type(uint256).max);
        bytes32 id1 = escrow.createIntent(address(usdc), 100e6, hashUSDC);
        vm.stopPrank();
        
        // Create intent with DAI
        bytes32 hashDAI = keccak256(abi.encodePacked(
            provider, address(dai), uint96(100 ether), uint96(10 ether), saltDAI
        ));
        
        vm.startPrank(payer);
        deal(address(dai), payer, 100 ether);
        dai.approve(address(escrow), type(uint256).max);
        bytes32 id2 = escrow.createIntent(address(dai), 100 ether, hashDAI);
        vm.stopPrank();
        
        // Verify escrow holds both tokens correctly
        assertEq(usdc.balanceOf(address(escrow)), 100e6);
        assertEq(dai.balanceOf(address(escrow)), 100 ether);
        
        // Verify intents store correct tokens
        IAgentEscrow.Intent memory intent1 = escrow.getIntent(id1);
        IAgentEscrow.Intent memory intent2 = escrow.getIntent(id2);
        
        assertEq(intent1.token, address(usdc));
        assertEq(intent2.token, address(dai));
    }
}
SOLIDITY

echo "✅ Tests de sécurité corrigés"

