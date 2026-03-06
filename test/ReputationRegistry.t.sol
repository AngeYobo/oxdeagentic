// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {IReputationRegistry} from "../src/interfaces/IReputationRegistry.sol";

contract ReputationRegistryTest is Test {
    ReputationRegistry public registry;

    address public escrow = address(0xE5C);
    address public provider = address(0xAAA);
    address public payer = address(0xBBB);

    event ReputationUpdated(
        address indexed provider, uint16 newScore, int16 delta, address indexed payer, uint256 epochStart
    );

    function setUp() public {
        registry = new ReputationRegistry(escrow);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_Constructor() public {
        assertEq(registry.escrow(), escrow);
        assertEq(registry.MAX_SCORE(), 1000);
        assertEq(registry.MAX_COUNTERPARTY_GAIN_PER_EPOCH(), 50);
        assertEq(registry.EPOCH_SECONDS(), 28 days);
    }

    function test_Constructor_RevertZeroEscrow() public {
        vm.expectRevert("zero escrow");
        new ReputationRegistry(address(0));
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Access Control Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecordSuccess_RevertNonEscrow() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(IReputationRegistry.OnlyEscrow.selector);
        registry.recordSuccess(provider, payer, 10);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Basic Functionality Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecordSuccess_Basic() public {
        uint256 epochStart = registry.getCurrentEpoch();

        vm.prank(escrow);

        vm.expectEmit(true, true, false, true);
        emit ReputationUpdated(provider, 10, 10, payer, epochStart);

        registry.recordSuccess(provider, payer, 10);

        assertEq(registry.getScore(provider), 10);
        assertEq(registry.getCounterpartyGains(provider, payer), 10);
    }

    function test_RecordSuccess_Accumulates() public {
        vm.startPrank(escrow);

        registry.recordSuccess(provider, payer, 10);
        registry.recordSuccess(provider, payer, 15);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 25);
        assertEq(registry.getCounterpartyGains(provider, payer), 25);
    }

    function test_RecordSuccess_MultiplePayers() public {
        address payer2 = address(0xCCC);

        vm.startPrank(escrow);

        registry.recordSuccess(provider, payer, 10);
        registry.recordSuccess(provider, payer2, 20);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 30);
        assertEq(registry.getCounterpartyGains(provider, payer), 10);
        assertEq(registry.getCounterpartyGains(provider, payer2), 20);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // INV-5: Counterparty Cap Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecordSuccess_CounterpartyCapExact() public {
        vm.prank(escrow);
        registry.recordSuccess(provider, payer, 50); // Exactly at cap

        assertEq(registry.getScore(provider), 50);
        assertEq(registry.getCounterpartyGains(provider, payer), 50);
    }

    function test_RecordSuccess_CounterpartyCapExceeded_Clamped() public {
        vm.startPrank(escrow);

        // First gain: 30 points
        registry.recordSuccess(provider, payer, 30);
        assertEq(registry.getScore(provider), 30);

        // Second gain: request 30 more, but only 20 allowance remains
        // Should clamp to 20
        vm.expectEmit(true, true, false, true);
        emit ReputationUpdated(provider, 50, 20, payer, registry.getCurrentEpoch());

        registry.recordSuccess(provider, payer, 30);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 50); // 30 + 20 (clamped)
        assertEq(registry.getCounterpartyGains(provider, payer), 50); // Cap reached
    }

    function test_RecordSuccess_CounterpartyCapExhausted() public {
        vm.startPrank(escrow);

        // Exhaust cap
        registry.recordSuccess(provider, payer, 50);

        // Try to add more - should emit event but no score change
        uint256 epochStart = registry.getCurrentEpoch();
        vm.expectEmit(true, true, false, true);
        emit ReputationUpdated(provider, 50, 0, payer, epochStart);

        registry.recordSuccess(provider, payer, 10);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 50); // No change
        assertEq(registry.getCounterpartyGains(provider, payer), 50);
    }

    function test_RecordSuccess_CounterpartyCapResetsNextEpoch() public {
        vm.startPrank(escrow);

        // Exhaust cap in epoch 1
        registry.recordSuccess(provider, payer, 50);
        assertEq(registry.getScore(provider), 50);

        // Move to next epoch
        vm.warp(block.timestamp + 28 days);

        // Can gain again from same payer
        registry.recordSuccess(provider, payer, 30);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 80); // 50 + 30
        assertEq(registry.getCounterpartyGains(provider, payer), 30); // New epoch
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Score Saturation Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecordSuccess_ScoreSaturatesAtMax() public {
        vm.startPrank(escrow);

        // Build up to near max with multiple payers (skip address(0))
        for (uint160 i = 1; i <= 20; i++) // start from 1, not 0 {
            registry.recordSuccess(provider, address(i), 50);
        }
        // Score should be exactly 1000 (20 * 50)
        assertEq(registry.getScore(provider), 1000);

        // Try to add more - should saturate at 1000
        address newPayer = address(0xFFF);
        registry.recordSuccess(provider, newPayer, 50);

        vm.stopPrank();

        assertEq(registry.getScore(provider), 1000); // Still at max
    }

    function testFuzz_RecordSuccess_NeverExceedsMax(uint16 initialScore, uint16 gain) public {
        initialScore = uint16(bound(initialScore, 0, 1000));
        gain = uint16(bound(gain, 1, 50)); // Within single-call cap

        // Set initial score
        vm.store(
            address(registry),
            keccak256(abi.encode(provider, 1)), // scores[provider] slot
            bytes32(uint256(initialScore))
        );

        vm.prank(escrow);
        registry.recordSuccess(provider, payer, gain);

        uint16 finalScore = registry.getScore(provider);
        assertLe(finalScore, 1000);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Input Validation Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_RecordSuccess_RevertZeroProvider() public {
        vm.prank(escrow);
        vm.expectRevert("zero provider");
        registry.recordSuccess(address(0), payer, 10);
    }

    function test_RecordSuccess_RevertZeroPayer() public {
        vm.prank(escrow);
        vm.expectRevert("zero payer");
        registry.recordSuccess(provider, address(0), 10);
    }

    function test_RecordSuccess_RevertZeroGain() public {
        vm.prank(escrow);
        vm.expectRevert("zero gain");
        registry.recordSuccess(provider, payer, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Epoch Tests
    // ══════════════════════════════════════════════════════════════════════════════

    function test_GetCurrentEpoch() public {
        // Epoch 0: timestamp 0
        vm.warp(0);
        assertEq(registry.getCurrentEpoch(), 0);

        // Epoch 0: timestamp 1 day
        vm.warp(1 days);
        assertEq(registry.getCurrentEpoch(), 0);

        // Epoch 1: timestamp 28 days
        vm.warp(28 days);
        assertEq(registry.getCurrentEpoch(), 28 days);

        // Epoch 1: timestamp 29 days
        vm.warp(29 days);
        assertEq(registry.getCurrentEpoch(), 28 days);

        // Epoch 2: timestamp 56 days
        vm.warp(56 days);
        assertEq(registry.getCurrentEpoch(), 56 days);
    }

    function testFuzz_GetCurrentEpoch_AlwaysMultipleOf28Days(uint256 timestamp) public {
        timestamp = bound(timestamp, 0, type(uint128).max);
        vm.warp(timestamp);

        uint256 epoch = registry.getCurrentEpoch();
        assertEq(epoch % 28 days, 0);
        assertLe(epoch, timestamp);
        assertGt(epoch + 28 days, timestamp);
    }
}
