// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StakeManager} from "../src/StakeManager.sol";
import {IStakeManager} from "../src/interfaces/IStakeManager.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockInsurancePool} from "./mocks/MockInsurancePool.sol";

contract StakeManagerTest is Test {
    StakeManager public stakeManager;
    MockERC20 public token;
    MockInsurancePool public insurancePool;
    
    address public escrow = address(0xE5C);
    address public provider = address(0xAAA);
    address public provider2 = address(0xBBB);
    
    bytes32 public intentId = keccak256("intent1");
    bytes32 public intentId2 = keccak256("intent2");
    
    uint256 constant INITIAL_BALANCE = 1000 ether;
    
    event StakeDeposited(address indexed provider, address indexed token, uint256 amount);
    event StakeWithdrawn(address indexed provider, address indexed token, uint256 amount);
    event StakeLocked(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    event StakeUnlocked(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    event StakeSlashed(bytes32 indexed intentId, address indexed provider, address indexed token, uint256 amount);
    
    function setUp() public {
        // Deploy mocks
        token = new MockERC20("Test Token", "TEST", 18);
        insurancePool = new MockInsurancePool();
        
        // Deploy StakeManager
        stakeManager = new StakeManager(escrow, address(insurancePool));
        
        // Setup provider balances
        token.mint(provider, INITIAL_BALANCE);
        token.mint(provider2, INITIAL_BALANCE);
        
        // Approve StakeManager
        vm.prank(provider);
        token.approve(address(stakeManager), type(uint256).max);
        
        vm.prank(provider2);
        token.approve(address(stakeManager), type(uint256).max);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_Constructor() public view {
        assertEq(stakeManager.escrow(), escrow);
        assertEq(stakeManager.insurancePool(), address(insurancePool));
        assertEq(stakeManager.MAX_SLASH_BPS(), 5000);
    }
    
    function test_Constructor_RevertZeroEscrow() public {
        vm.expectRevert(IStakeManager.ZeroAddress.selector);
        new StakeManager(address(0), address(insurancePool));
    }
    
    function test_Constructor_RevertZeroInsurancePool() public {
        vm.expectRevert(IStakeManager.ZeroAddress.selector);
        new StakeManager(escrow, address(0));
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Deposit Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_DepositStake() public {
        uint256 amount = 100 ether;
        
        vm.prank(provider);
        vm.expectEmit(true, true, false, true);
        emit StakeDeposited(provider, address(token), amount);
        
        stakeManager.depositStake(address(token), amount);
        
        assertEq(stakeManager.totalStake(provider, address(token)), amount);
        assertEq(stakeManager.availableStake(provider, address(token)), amount);
        assertEq(token.balanceOf(address(stakeManager)), amount);
    }
    
    function test_DepositStake_Multiple() public {
        vm.startPrank(provider);
        
        stakeManager.depositStake(address(token), 50 ether);
        stakeManager.depositStake(address(token), 30 ether);
        
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 80 ether);
    }
    
    function test_DepositStake_RevertZeroToken() public {
        vm.prank(provider);
        vm.expectRevert(IStakeManager.ZeroAddress.selector);
        stakeManager.depositStake(address(0), 100 ether);
    }
    
    function test_DepositStake_RevertZeroAmount() public {
        vm.prank(provider);
        vm.expectRevert(IStakeManager.ZeroAmount.selector);
        stakeManager.depositStake(address(token), 0);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Withdraw Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_WithdrawStake() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawAmount = 60 ether;
        
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), depositAmount);
        
        vm.expectEmit(true, true, false, true);
        emit StakeWithdrawn(provider, address(token), withdrawAmount);
        
        stakeManager.withdrawStake(address(token), withdrawAmount);
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 40 ether);
        assertEq(token.balanceOf(provider), INITIAL_BALANCE - 40 ether);
    }
    
    function test_WithdrawStake_Full() public {
        uint256 amount = 100 ether;
        
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), amount);
        stakeManager.withdrawStake(address(token), amount);
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 0);
        assertEq(token.balanceOf(provider), INITIAL_BALANCE);
    }
    
    function test_WithdrawStake_RevertInsufficientStake() public {
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), 50 ether);
        
        vm.expectRevert(IStakeManager.InsufficientStake.selector);
        stakeManager.withdrawStake(address(token), 51 ether);
        vm.stopPrank();
    }
    
    function test_WithdrawStake_RevertWithLocked() public {
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        vm.stopPrank();
        
        // Lock 60 ether
        vm.prank(escrow);
        stakeManager.lockStake(provider, address(token), 60 ether, intentId);
        
        // Try to withdraw more than available (40 ether)
        vm.prank(provider);
        vm.expectRevert(IStakeManager.InsufficientStake.selector);
        stakeManager.withdrawStake(address(token), 41 ether);
    }
    
    function test_WithdrawStake_SuccessWithLocked() public {
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        vm.stopPrank();
        
        // Lock 60 ether
        vm.prank(escrow);
        stakeManager.lockStake(provider, address(token), 60 ether, intentId);
        
        // Can withdraw available 40 ether
        vm.prank(provider);
        stakeManager.withdrawStake(address(token), 40 ether);
        
        assertEq(stakeManager.totalStake(provider, address(token)), 60 ether);
        assertEq(stakeManager.lockedStake(provider, address(token)), 60 ether);
        assertEq(stakeManager.availableStake(provider, address(token)), 0);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Lock Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_LockStake() public {
        uint256 depositAmount = 100 ether;
        uint256 lockAmount = 60 ether;
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), depositAmount);
        
        vm.prank(escrow);
        vm.expectEmit(true, true, true, true);
        emit StakeLocked(intentId, provider, address(token), lockAmount);
        
        stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        
        assertEq(stakeManager.totalStake(provider, address(token)), depositAmount);
        assertEq(stakeManager.lockedStake(provider, address(token)), lockAmount);
        assertEq(stakeManager.availableStake(provider, address(token)), 40 ether);
        
        IStakeManager.StakeLock memory lock = stakeManager.intentLocks(intentId);
        assertEq(lock.provider, provider);
        assertEq(lock.token, address(token));
        assertEq(lock.amount, lockAmount);
        assertTrue(lock.active);
    }
    
    function test_LockStake_Multiple() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 30 ether, intentId);
        stakeManager.lockStake(provider, address(token), 40 ether, intentId2);
        vm.stopPrank();
        
        assertEq(stakeManager.lockedStake(provider, address(token)), 70 ether);
        assertEq(stakeManager.availableStake(provider, address(token)), 30 ether);
    }
    
    function test_LockStake_RevertNonEscrow() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.prank(address(0xBAD));
        vm.expectRevert(IStakeManager.OnlyEscrow.selector);
        stakeManager.lockStake(provider, address(token), 50 ether, intentId);
    }
    
    function test_LockStake_RevertInsufficientStake() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.prank(escrow);
        vm.expectRevert(IStakeManager.InsufficientStake.selector);
        stakeManager.lockStake(provider, address(token), 101 ether, intentId);
    }
    
    function test_LockStake_RevertLockAlreadyExists() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 30 ether, intentId);
        
        vm.expectRevert(IStakeManager.LockAlreadyExists.selector);
        stakeManager.lockStake(provider, address(token), 20 ether, intentId);
        vm.stopPrank();
    }
    
    function test_LockStake_RevertZeroProvider() public {
        vm.prank(escrow);
        vm.expectRevert(IStakeManager.ZeroAddress.selector);
        stakeManager.lockStake(address(0), address(token), 50 ether, intentId);
    }
    
    function test_LockStake_RevertZeroToken() public {
        vm.prank(escrow);
        vm.expectRevert(IStakeManager.ZeroAddress.selector);
        stakeManager.lockStake(provider, address(0), 50 ether, intentId);
    }
    
    function test_LockStake_RevertZeroAmount() public {
        vm.prank(escrow);
        vm.expectRevert(IStakeManager.ZeroAmount.selector);
        stakeManager.lockStake(provider, address(token), 0, intentId);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Unlock Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_UnlockStake() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 60 ether, intentId);
        
        vm.expectEmit(true, true, true, true);
        emit StakeUnlocked(intentId, provider, address(token), 60 ether);
        
        stakeManager.unlockStake(intentId);
        vm.stopPrank();
        
        assertEq(stakeManager.lockedStake(provider, address(token)), 0);
        assertEq(stakeManager.availableStake(provider, address(token)), 100 ether);
        
        IStakeManager.StakeLock memory lock = stakeManager.intentLocks(intentId);
        assertFalse(lock.active);
    }
    
    function test_UnlockStake_Idempotent() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 60 ether, intentId);
        stakeManager.unlockStake(intentId);
        
        // Second unlock should be no-op
        stakeManager.unlockStake(intentId);
        vm.stopPrank();
        
        assertEq(stakeManager.lockedStake(provider, address(token)), 0);
    }
    
    function test_UnlockStake_NonExistent() public {
        // Unlocking non-existent lock should be no-op
        vm.prank(escrow);
        stakeManager.unlockStake(intentId);
    }
    
    function test_UnlockStake_RevertNonEscrow() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(IStakeManager.OnlyEscrow.selector);
        stakeManager.unlockStake(intentId);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Slash Tests (INV-1)
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_Slash() public {
        uint256 lockAmount = 100 ether;
        uint256 slashAmount = 40 ether; // 40% < 50% cap
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), lockAmount);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        
        vm.expectEmit(true, true, true, true);
        emit StakeSlashed(intentId, provider, address(token), slashAmount);
        
        stakeManager.slash(intentId, slashAmount);
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 60 ether);
        assertEq(stakeManager.lockedStake(provider, address(token)), 60 ether);
        assertEq(token.balanceOf(address(insurancePool)), slashAmount);
        assertEq(insurancePool.notifiedAmount(), slashAmount);
        
        IStakeManager.StakeLock memory lock = stakeManager.intentLocks(intentId);
        assertEq(lock.amount, 60 ether);
        assertTrue(lock.active);
    }
    
    function test_Slash_ExactlyCap() public {
        uint256 lockAmount = 100 ether;
        uint256 slashAmount = 50 ether; // Exactly 50%
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), lockAmount);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        stakeManager.slash(intentId, slashAmount);
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 50 ether);
    }
    
    function test_Slash_RevertExceedsCap() public {
        uint256 lockAmount = 100 ether;
        uint256 slashAmount = 51 ether; // 51% > 50% cap
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), lockAmount);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        
        vm.expectRevert(IStakeManager.SlashExceedsCap.selector);
        stakeManager.slash(intentId, slashAmount);
        vm.stopPrank();
    }
    
    function test_Slash_RevertLockNotFound() public {
        vm.prank(escrow);
        vm.expectRevert(IStakeManager.LockNotFound.selector);
        stakeManager.slash(intentId, 10 ether);
    }
    
    function test_Slash_RevertLockNotActive() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 100 ether, intentId);
        stakeManager.unlockStake(intentId);
        
        vm.expectRevert(IStakeManager.LockNotActive.selector);
        stakeManager.slash(intentId, 10 ether);
        vm.stopPrank();
    }
    
    function test_Slash_RevertZeroAmount() public {
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), 100 ether, intentId);
        
        vm.expectRevert(IStakeManager.ZeroAmount.selector);
        stakeManager.slash(intentId, 0);
        vm.stopPrank();
    }
    
    function test_Slash_RevertNonEscrow() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(IStakeManager.OnlyEscrow.selector);
        stakeManager.slash(intentId, 10 ether);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Integration Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function test_FullLifecycle() public {
        // 1. Provider deposits stake
        vm.prank(provider);
        stakeManager.depositStake(address(token), 300 ether);
        
        assertEq(stakeManager.availableStake(provider, address(token)), 300 ether);
        
        // 2. Lock stake for intent (3x)
        vm.prank(escrow);
        stakeManager.lockStake(provider, address(token), 30 ether, intentId);
        
        assertEq(stakeManager.availableStake(provider, address(token)), 270 ether);
        
        // 3. Intent settles successfully, unlock
        vm.prank(escrow);
        stakeManager.unlockStake(intentId);
        
        assertEq(stakeManager.availableStake(provider, address(token)), 300 ether);
        
        // 4. Provider withdraws
        vm.prank(provider);
        stakeManager.withdrawStake(address(token), 300 ether);
        
        assertEq(stakeManager.totalStake(provider, address(token)), 0);
    }
    
    function test_FullLifecycle_WithSlash() public {
        // 1. Deposit
        vm.prank(provider);
        stakeManager.depositStake(address(token), 300 ether);
        
        // 2. Lock
        vm.prank(escrow);
        stakeManager.lockStake(provider, address(token), 30 ether, intentId);
        
        // 3. Slash 30% (within 50% cap)
        vm.prank(escrow);
        stakeManager.slash(intentId, 9 ether); // 30% of 30 ether
        
        assertEq(stakeManager.totalStake(provider, address(token)), 291 ether);
        assertEq(stakeManager.lockedStake(provider, address(token)), 21 ether);
        
        // 4. Unlock
        vm.prank(escrow);
        stakeManager.unlockStake(intentId);
        
        assertEq(stakeManager.availableStake(provider, address(token)), 291 ether);
        
        // 5. Withdraw
        vm.prank(provider);
        stakeManager.withdrawStake(address(token), 291 ether);
    }
    
    function test_MultipleProviders() public {
        // Provider 1
        vm.prank(provider);
        stakeManager.depositStake(address(token), 100 ether);
        
        // Provider 2
        vm.prank(provider2);
        stakeManager.depositStake(address(token), 200 ether);
        
        assertEq(stakeManager.totalStake(provider, address(token)), 100 ether);
        assertEq(stakeManager.totalStake(provider2, address(token)), 200 ether);
        
        // Lock for provider 1
        vm.prank(escrow);
        stakeManager.lockStake(provider, address(token), 60 ether, intentId);
        
        assertEq(stakeManager.availableStake(provider, address(token)), 40 ether);
        assertEq(stakeManager.availableStake(provider2, address(token)), 200 ether);
    }
    
    // ══════════════════════════════════════════════════════════════════════════════
    // Fuzz Tests
    // ══════════════════════════════════════════════════════════════════════════════
    
    function testFuzz_DepositWithdraw(uint256 amount) public {
        amount = bound(amount, 1, INITIAL_BALANCE);
        
        vm.startPrank(provider);
        stakeManager.depositStake(address(token), amount);
        stakeManager.withdrawStake(address(token), amount);
        vm.stopPrank();
        
        assertEq(stakeManager.totalStake(provider, address(token)), 0);
        assertEq(token.balanceOf(provider), INITIAL_BALANCE);
    }
    
    function testFuzz_SlashNeverExceedsCap(uint96 lockAmount, uint96 slashAmount) public {
        vm.assume(lockAmount > 0);
        vm.assume(lockAmount <= INITIAL_BALANCE);
        vm.assume(slashAmount > 0);
        
        uint256 maxSlash = (uint256(lockAmount) * 5000) / 10_000;
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), lockAmount);
        
        vm.startPrank(escrow);
        stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        
        if (slashAmount <= maxSlash) {
            stakeManager.slash(intentId, slashAmount);
            assertEq(token.balanceOf(address(insurancePool)), slashAmount);
        } else {
            vm.expectRevert(IStakeManager.SlashExceedsCap.selector);
            stakeManager.slash(intentId, slashAmount);
        }
        vm.stopPrank();
    }
    
    function testFuzz_AvailableStakeAlwaysCorrect(
        uint256 depositAmount,
        uint256 lockAmount
    ) public {
        depositAmount = bound(depositAmount, 1, INITIAL_BALANCE);
        lockAmount = bound(lockAmount, 0, depositAmount);
        
        vm.prank(provider);
        stakeManager.depositStake(address(token), depositAmount);
        
        if (lockAmount > 0) {
            vm.prank(escrow);
            stakeManager.lockStake(provider, address(token), lockAmount, intentId);
        }
        
        uint256 total = stakeManager.totalStake(provider, address(token));
        uint256 locked = stakeManager.lockedStake(provider, address(token));
        uint256 available = stakeManager.availableStake(provider, address(token));
        
        assertEq(total, depositAmount);
        assertEq(locked, lockAmount);
        assertEq(available, depositAmount - lockAmount);
        assertEq(total, locked + available);
    }
}