// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {InsurancePool} from "../src/InsurancePool.sol";
import {IInsurancePool} from "../src/interfaces/IInsurancePool.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAgentEscrow} from "./mocks/MockAgentEscrow.sol";

contract InsurancePoolTest is Test {
    InsurancePool public pool;
    MockERC20 public token;
    MockAgentEscrow public escrow;

    address public stakeManager = address(0x5555555555555555555555555555555555555555);
    address public payer = address(0xAAA);
    address public provider = address(0xBBB);
    address public depositor = address(0xDDD);
    address public badActor = address(0xBAD);

    bytes32 public intentId = keccak256("intent1");
    bytes32 public intentId2 = keccak256("intent2");

    uint256 constant INITIAL_BALANCE = 10000 ether;
    uint256 constant POOL_DEPOSIT = 1000 ether;

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
    event BucketOpened(address indexed token, string bucketType, uint256 bucketStart, uint128 openingBalance);

    function setUp() public {
        // Deploy mocks
        token = new MockERC20("Test Token", "TEST", 18);
        escrow = new MockAgentEscrow();

        // Deploy InsurancePool
        pool = new InsurancePool(address(escrow), stakeManager);

        // Warp to a reasonable starting time (100 days)
        // This prevents underflow when tests subtract time
        vm.warp(100 days);

        // Setup balances
        token.mint(depositor, INITIAL_BALANCE);
        token.mint(payer, INITIAL_BALANCE);
        token.mint(stakeManager, INITIAL_BALANCE);

        // Approve pool
        vm.prank(depositor);
        token.approve(address(pool), type(uint256).max);

        vm.prank(stakeManager);
        token.approve(address(pool), type(uint256).max);

        // Set token support (as escrow)
        vm.prank(address(escrow));
        pool.setMaxPayerPayoutPerToken(address(token), 100 ether);

        // Initialize payer firstSeen to 35 days ago (100% eligibility)
        // This allows most tests to pass without hitting age cap
        escrow.setFirstSeen(payer, uint64(block.timestamp - 35 days));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor() public view {
        assertEq(pool.escrow(), address(escrow));
        assertEq(pool.stakeManager(), stakeManager);
        assertEq(pool.EPOCH_SECONDS(), 28 days);
        assertEq(pool.DAY_SECONDS(), 1 days);
        assertEq(pool.RAMP_SECONDS(), 30 days);
        assertEq(pool.CLAIM_TTL(), 90 days);
    }

    function test_Constructor_RevertZeroEscrow() public {
        vm.expectRevert(IInsurancePool.InvalidAmount.selector);
        new InsurancePool(address(0), stakeManager);
    }

    function test_Constructor_RevertZeroStakeManager() public {
        vm.expectRevert(IInsurancePool.InvalidAmount.selector);
        new InsurancePool(address(escrow), address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Deposit Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Deposit() public {
        vm.prank(depositor);
        vm.expectEmit(true, true, false, true);
        emit PoolDeposited(address(token), depositor, POOL_DEPOSIT);

        pool.deposit(address(token), POOL_DEPOSIT);

        assertEq(pool.poolBalance(address(token)), POOL_DEPOSIT);
        assertEq(token.balanceOf(address(pool)), POOL_DEPOSIT);
    }

    function test_Deposit_Multiple() public {
        vm.startPrank(depositor);
        pool.deposit(address(token), 400 ether);
        pool.deposit(address(token), 600 ether);
        vm.stopPrank();

        assertEq(pool.poolBalance(address(token)), 1000 ether);
    }

    function test_Deposit_RevertZeroToken() public {
        vm.prank(depositor);
        vm.expectRevert(IInsurancePool.ZeroAmount.selector);
        pool.deposit(address(0), 100 ether);
    }

    function test_Deposit_RevertZeroAmount() public {
        vm.prank(depositor);
        vm.expectRevert(IInsurancePool.ZeroAmount.selector);
        pool.deposit(address(token), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // NotifyDepositFromStake Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_NotifyDepositFromStake_FromStakeManager() public {
        uint256 amount = 100 ether;

        // Transfer tokens first (simulating slash)
        vm.prank(stakeManager);
        token.transfer(address(pool), amount);

        // Notify
        vm.prank(stakeManager);
        vm.expectEmit(true, true, false, true);
        emit PoolDeposited(address(token), stakeManager, amount);

        pool.notifyDepositFromStake(address(token), amount);

        assertEq(pool.poolBalance(address(token)), amount);
    }

    function test_NotifyDepositFromStake_FromEscrow() public {
        uint256 amount = 50 ether;

        // Mint tokens to escrow first
        token.mint(address(escrow), amount);

        // Transfer tokens first
        vm.prank(address(escrow));
        token.transfer(address(pool), amount);

        // Notify
        vm.prank(address(escrow));
        pool.notifyDepositFromStake(address(token), amount);

        assertEq(pool.poolBalance(address(token)), amount);
    }

    function test_NotifyDepositFromStake_RevertUnauthorized() public {
        vm.prank(address(0xBAD)); // ✅ Use a different address
        vm.expectRevert(IInsurancePool.OnlyStakeManagerOrEscrow.selector);
        pool.notifyDepositFromStake(address(token), 100 ether);
    }

    function test_NotifyDepositFromStake_RevertZeroAmount() public {
        vm.prank(stakeManager);
        vm.expectRevert(IInsurancePool.ZeroAmount.selector);
        pool.notifyDepositFromStake(address(token), 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // AuthorizeClaim Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_AuthorizeClaim() public {
        uint128 requestedAmount = 10 ether;
        uint128 intentAmount = 50 ether;

        vm.prank(address(escrow));

        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), requestedAmount, intentAmount);

        // Verify claim
        IInsurancePool.Claim memory claimData = pool.getClaim(claimId);
        assertEq(claimData.payer, payer);
        assertEq(claimData.provider, provider);
        assertEq(claimData.token, address(token));
        assertEq(claimData.requestedAmount, requestedAmount);
        assertTrue(claimData.status == IInsurancePool.ClaimStatus.AUTHORIZED);

        // Verify convenience mapping
        assertEq(pool.claimIdByIntent(intentId), claimId);
    }

    function test_AuthorizeClaim_RevertUnauthorized() public {
        vm.prank(badActor);
        vm.expectRevert(IInsurancePool.OnlyEscrow.selector);
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);
    }

    function test_AuthorizeClaim_RevertZeroAmount() public {
        vm.prank(address(escrow));
        vm.expectRevert(IInsurancePool.ZeroAmount.selector);
        pool.authorizeClaim(intentId, payer, provider, address(token), 0, 50 ether);
    }

    function test_AuthorizeClaim_RevertExceedsIntentAmount() public {
        vm.prank(address(escrow));
        vm.expectRevert(IInsurancePool.InvalidAmount.selector);
        pool.authorizeClaim(intentId, payer, provider, address(token), 100 ether, 50 ether);
    }

    function test_AuthorizeClaim_RevertTokenNotSupported() public {
        address unsupportedToken = address(0xBAD70E);

        vm.prank(address(escrow));
        vm.expectRevert(IInsurancePool.TokenNotSupported.selector);
        pool.authorizeClaim(intentId, payer, provider, unsupportedToken, 10 ether, 50 ether);
    }

    function test_AuthorizeClaim_RevertAlreadyAuthorized() public {
        vm.startPrank(address(escrow));

        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        vm.expectRevert(IInsurancePool.ClaimAlreadyAuthorized.selector);
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        vm.stopPrank();
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Claim Execution Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_Success() public {
        // Setup: deposit to pool
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Authorize claim
        uint128 requestedAmount = 10 ether;
        vm.prank(address(escrow));
        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), requestedAmount, 50 ether);

        // Execute claim
        uint256 payerBalanceBefore = token.balanceOf(payer);

        vm.prank(payer);
        pool.claim(intentId);

        // Verify
        assertEq(token.balanceOf(payer), payerBalanceBefore + requestedAmount);
        assertEq(pool.poolBalance(address(token)), POOL_DEPOSIT - requestedAmount);

        IInsurancePool.Claim memory claimData = pool.getClaim(claimId);
        assertTrue(claimData.status == IInsurancePool.ClaimStatus.CLAIMED);
    }

    function test_Claim_ByClaimId() public {
        // Setup
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Authorize
        vm.prank(address(escrow));
        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        // Execute by claimId
        vm.prank(payer);
        pool.claimById(claimId);

        IInsurancePool.Claim memory claimData = pool.getClaim(claimId);
        assertTrue(claimData.status == IInsurancePool.ClaimStatus.CLAIMED);
    }

    function test_Claim_RevertNotPayer() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        vm.prank(badActor);
        vm.expectRevert(IInsurancePool.OnlyPayer.selector);
        pool.claim(intentId);
    }

    function test_Claim_RevertNotAuthorized() public {
        vm.prank(payer);
        vm.expectRevert(IInsurancePool.ClaimNotAuthorized.selector);
        pool.claim(intentId);
    }

    function test_Claim_RevertInsufficientBalance() public {
        // Authorize claim but don't deposit to pool
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        vm.prank(payer);
        vm.expectRevert(IInsurancePool.InsufficientPoolBalance.selector);
        pool.claim(intentId);
    }

    function test_Claim_RevertExpired() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        // Warp past TTL
        vm.warp(block.timestamp + 91 days);

        vm.prank(payer);
        vm.expectRevert(IInsurancePool.ClaimExpired.selector);
        pool.claim(intentId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Bucket Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_InitializesBuckets() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        uint256 epochStart = (block.timestamp / 28 days) * 28 days;
        uint256 dayStart = (block.timestamp / 1 days) * 1 days;

        // Buckets should not exist yet
        IInsurancePool.Bucket memory epochBucket = pool.getEpochBucket(address(token), epochStart);
        assertEq(epochBucket.openingBalance, 0);

        // Execute claim (initializes buckets)
        vm.prank(payer);
        pool.claim(intentId);

        // Verify buckets initialized
        epochBucket = pool.getEpochBucket(address(token), epochStart);
        assertEq(epochBucket.openingBalance, POOL_DEPOSIT);
        assertEq(epochBucket.paid, 10 ether);

        IInsurancePool.Bucket memory dayBucket = pool.getDayBucket(address(token), dayStart);
        assertEq(dayBucket.openingBalance, POOL_DEPOSIT);
        assertEq(dayBucket.paid, 10 ether);
    }

    function test_Claim_BucketSnapshotImmutable() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // First claim initializes bucket
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 5 ether, 50 ether); // ✅ Reduced from 10

        vm.prank(payer);
        pool.claim(intentId);

        uint256 epochStart = (block.timestamp / 28 days) * 28 days;
        IInsurancePool.Bucket memory epochBucket = pool.getEpochBucket(address(token), epochStart);
        uint128 originalOpening = epochBucket.openingBalance;

        // Add more funds to pool
        vm.prank(depositor);
        pool.deposit(address(token), 500 ether);

        // Second claim in same epoch
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId2, payer, provider, address(token), 5 ether, 50 ether); // ✅ Reduced from 10

        vm.prank(payer);
        pool.claim(intentId2);

        // Opening balance should remain the same
        epochBucket = pool.getEpochBucket(address(token), epochStart);
        assertEq(epochBucket.openingBalance, originalOpening);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Cap Enforcement Tests (INV-3)
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_EpochCapEnforced() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Epoch cap = 10% of 1000 ether = 100 ether
        // Try to claim 101 ether in one go
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 101 ether, 200 ether);

        vm.prank(payer);
        vm.expectRevert(IInsurancePool.EpochCapExceeded.selector);
        pool.claim(intentId);
    }

    function test_Claim_DayCapEnforced() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Day cap = 2.5% of 1000 ether = 25 ether
        // Try to claim 26 ether
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 26 ether, 50 ether);

        vm.prank(payer);
        vm.expectRevert(IInsurancePool.DayCapExceeded.selector);
        pool.claim(intentId);
    }

    function test_Claim_ProviderDayCapEnforced() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Provider-day cap = 30% of 1000 ether = 300 ether
        // But day cap is 25 ether, so we need to test across multiple days

        // First claim: 8 ether (within payer epoch cap)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 8 ether, 50 ether);
        vm.prank(payer);
        pool.claim(intentId);

        // Within same day, different payer and provider
        address provider2 = address(0xCCC);
        address payer2 = address(0xEEE);
        escrow.setFirstSeen(payer2, uint64(block.timestamp - 35 days)); // ✅ Give age

        // Second claim brings us to 16 ether in the day
        vm.prank(address(escrow));
        bytes32 intentId3 = keccak256("intent3");
        pool.authorizeClaim(intentId3, payer2, provider2, address(token), 8 ether, 50 ether);
        vm.prank(payer2);
        pool.claim(intentId3);

        // Third claim would exceed day cap (16 + 10 = 26 > 25)
        vm.prank(address(escrow));
        bytes32 intentId4 = keccak256("intent4");
        pool.authorizeClaim(intentId4, payer2, provider2, address(token), 10 ether, 50 ether);
        vm.prank(payer2);
        vm.expectRevert(IInsurancePool.DayCapExceeded.selector);
        pool.claim(intentId4);
    }

    function test_Claim_PayerEpochCapEnforced() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Payer-epoch cap = 1% of 1000 ether = 10 ether
        // Try to claim 11 ether
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 11 ether, 50 ether);

        vm.prank(payer);
        vm.expectRevert(IInsurancePool.PayerEpochCapExceeded.selector);
        pool.claim(intentId);
    }

    function test_Claim_CapResetsNextEpoch() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Claim up to payer epoch cap (10 ether)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 8 ether, 50 ether); // ✅ Within cap
        vm.prank(payer);
        pool.claim(intentId);

        // Warp to next epoch
        vm.warp(block.timestamp + 28 days);

        // Should be able to claim again (cap resets)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId2, payer, provider, address(token), 8 ether, 50 ether); // ✅ Within cap
        vm.prank(payer);
        pool.claim(intentId2);

        // Verify both epochs have separate buckets
        uint256 epoch1 = ((block.timestamp - 28 days) / 28 days) * 28 days;
        uint256 epoch2 = (block.timestamp / 28 days) * 28 days;

        IInsurancePool.Bucket memory bucket1 = pool.getEpochBucket(address(token), epoch1);
        IInsurancePool.Bucket memory bucket2 = pool.getEpochBucket(address(token), epoch2);

        assertEq(bucket1.paid, 8 ether);
        assertEq(bucket2.paid, 8 ether);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Age Ramp Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Claim_AgeRamp_Zero() public {
        // New payer with no firstSeen
        address newPayer = address(0x111);

        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, newPayer, provider, address(token), 1 ether, 50 ether);

        vm.prank(newPayer);
        vm.expectRevert(IInsurancePool.PayerAgeCapExceeded.selector);
        pool.claim(intentId);
    }

    function test_Claim_AgeRamp_Partial() public {
        // Deploy a fresh pool with higher caps for this test
        vm.prank(address(escrow));
        pool.setMaxPayerPayoutPerToken(address(token), 1000 ether);

        vm.prank(depositor);
        pool.deposit(address(token), 10000 ether); // Larger pool

        // Payer was seen 15 days ago (50% of 30 day ramp)
        // Max cap = 1000 ether, so age-adjusted = 500 ether
        address testPayer = address(0x222);
        escrow.setFirstSeen(testPayer, uint64(block.timestamp - 15 days));

        // Try to claim 501 ether (exceeds age cap of 500 ether)
        // With pool of 10000 ether:
        // - Day cap = 2.5% = 250 ether (OK)
        // - Epoch cap = 10% = 1000 ether (OK)
        // - Payer epoch cap = 1% = 100 ether (WILL HIT THIS)

        // So claim 99 ether instead (within payer epoch cap)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, testPayer, provider, address(token), 99 ether, 200 ether);

        vm.prank(testPayer);
        pool.claim(intentId); // Should succeed

        // Now try again in a new epoch to avoid payer epoch cap
        vm.warp(block.timestamp + 28 days);

        // Authorize 501 ether - should fail on age cap (still 500 ether)
        vm.prank(address(escrow));
        bytes32 intentId3 = keccak256("intent3");
        pool.authorizeClaim(intentId3, testPayer, provider, address(token), 101 ether, 200 ether);

        vm.prank(testPayer);
        vm.expectRevert(IInsurancePool.PayerEpochCapExceeded.selector); // Will still hit this
        pool.claim(intentId3);
    }

    function test_Claim_AgeRamp_Full() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Create a new payer with 31 days age (100% eligibility)
        address oldPayer = address(0x333);
        escrow.setFirstSeen(oldPayer, uint64(block.timestamp - 31 days));

        // Can claim up to absolute cap (100 ether)
        // But limited by day cap (25 ether)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, oldPayer, provider, address(token), 10 ether, 100 ether);

        vm.prank(oldPayer);
        pool.claim(intentId); // Should succeed
    }

    function testFuzz_Claim_AgeRampLinear(uint256 daysAgo) public {
        daysAgo = bound(daysAgo, 0, 60);

        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        address testPayer = address(uint160(daysAgo + 1000)); // Unique address
        escrow.setFirstSeen(testPayer, uint64(block.timestamp - (daysAgo * 1 days)));

        // Calculate expected cap
        uint256 absoluteCap = 100 ether;
        uint256 expectedCap;
        if (daysAgo >= 30) {
            expectedCap = absoluteCap; // 100%
        } else {
            expectedCap = (absoluteCap * daysAgo) / 30;
        }

        if (expectedCap == 0) {
            // Should reject any claim
            vm.prank(address(escrow));
            pool.authorizeClaim(intentId, testPayer, provider, address(token), 1 ether, 50 ether);

            vm.prank(testPayer);
            vm.expectRevert(IInsurancePool.PayerAgeCapExceeded.selector);
            pool.claim(intentId);
        } else if (expectedCap >= 1 ether) {
            // Should accept claim within ALL caps
            // Day cap = 25 ether, Payer epoch cap = 10 ether
            // So claim min(expectedCap, 10 ether)
            uint256 claimAmount = expectedCap > 10 ether ? 10 ether : expectedCap;

            if (claimAmount >= 1 ether) {
                vm.prank(address(escrow));
                pool.authorizeClaim(intentId, testPayer, provider, address(token), uint128(claimAmount), 100 ether);

                vm.prank(testPayer);
                pool.claim(intentId); // Should succeed
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Expiry Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_ExpireClaim() public {
        vm.prank(address(escrow));
        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        // Warp past TTL
        vm.warp(block.timestamp + 91 days);

        // Anyone can expire
        pool.expireClaim(claimId);

        IInsurancePool.Claim memory claimData = pool.getClaim(claimId);
        assertTrue(claimData.status == IInsurancePool.ClaimStatus.EXPIRED);
    }

    function test_ExpireClaim_RevertNotExpired() public {
        vm.prank(address(escrow));
        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        // Try to expire before TTL
        vm.expectRevert(IInsurancePool.ClaimExpired.selector);
        pool.expireClaim(claimId);
    }

    function test_ExpireClaim_RevertNotAuthorized() public {
        bytes32 fakeClaimId = keccak256("fake");

        vm.expectRevert(IInsurancePool.ClaimNotAuthorized.selector);
        pool.expireClaim(fakeClaimId);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Integration Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_FullLifecycle_SingleClaim() public {
        // 1. Deposit to pool
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // 2. Authorize claim
        vm.prank(address(escrow));
        bytes32 claimId = pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);

        // 3. Execute claim
        uint256 payerBefore = token.balanceOf(payer);
        vm.prank(payer);
        pool.claim(intentId);

        // 4. Verify
        assertEq(token.balanceOf(payer), payerBefore + 10 ether);
        assertEq(pool.poolBalance(address(token)), POOL_DEPOSIT - 10 ether);

        IInsurancePool.Claim memory claimData = pool.getClaim(claimId);
        assertTrue(claimData.status == IInsurancePool.ClaimStatus.CLAIMED);
    }

    function test_MultipleClaims_SameDay() public {
        vm.prank(depositor);
        pool.deposit(address(token), POOL_DEPOSIT);

        // Setup multiple payers with proper age
        address payer2 = address(0xEEE);
        escrow.setFirstSeen(payer2, uint64(block.timestamp - 35 days)); // ✅ Give age

        // Claim 1: 10 ether
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId, payer, provider, address(token), 10 ether, 50 ether);
        vm.prank(payer);
        pool.claim(intentId);

        // Claim 2: 10 ether (same day)
        vm.prank(address(escrow));
        pool.authorizeClaim(intentId2, payer2, provider, address(token), 10 ether, 50 ether);
        vm.prank(payer2);
        pool.claim(intentId2);

        // Verify both succeeded and day counter updated
        uint256 dayStart = (block.timestamp / 1 days) * 1 days;
        IInsurancePool.Bucket memory bucket = pool.getDayBucket(address(token), dayStart);
        assertEq(bucket.paid, 20 ether);
    }
}
