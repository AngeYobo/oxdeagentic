// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../../src/ReputationRegistry.sol";

contract ReputationHandler is Test {
    ReputationRegistry public registry;
    address public escrow;
    
    // Track all providers and payers for invariant checking
    address[] public providersList;
    address[] public payersList;
    mapping(address => bool) public isProvider;
    mapping(address => bool) public isPayer;
    
    constructor(ReputationRegistry _registry, address _escrow) {
        registry = _registry;
        escrow = _escrow;
    }
    
    // Add getter functions for array lengths
    function providersCount() external view returns (uint256) {
        return providersList.length;
    }
    
    function payersCount() external view returns (uint256) {
        return payersList.length;
    }
    
    function getProvider(uint256 index) external view returns (address) {
        return providersList[index];
    }
    
    function getPayer(uint256 index) external view returns (address) {
        return payersList[index];
    }
    
    function recordSuccess(uint8 providerSeed, uint8 payerSeed, uint16 gain) public {
        gain = uint16(bound(gain, 1, 100)); // Realistic gain range
        
        address provider = address(uint160(providerSeed) + 1); // Avoid zero
        address payer = address(uint160(payerSeed) + 1);
        
        // Track for invariant checking
        if (!isProvider[provider]) {
            providersList.push(provider);
            isProvider[provider] = true;
        }
        if (!isPayer[payer]) {
            payersList.push(payer);
            isPayer[payer] = true;
        }
        
        vm.prank(escrow);
        registry.recordSuccess(provider, payer, gain);
    }
    
    function warpTime(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, 0, 365 days);
        vm.warp(block.timestamp + timeDelta);
    }
}

contract ReputationInvariantsTest is Test {
    ReputationRegistry public registry;
    ReputationHandler public handler;
    address public escrow = address(0xE5C);
    
    function setUp() public {
        registry = new ReputationRegistry(escrow);
        handler = new ReputationHandler(registry, escrow);
        
        targetContract(address(handler));
        
        // Focus fuzzing on the main interaction
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ReputationHandler.recordSuccess.selector;
        selectors[1] = ReputationHandler.warpTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }
    
    /// @custom:invariant Score never exceeds MAX_SCORE (1000)
    function invariant_ScoreNeverExceedsMax() public view {
        uint256 providerCount = handler.providersCount();
        for (uint256 i = 0; i < providerCount; i++) {
            address provider = handler.getProvider(i);
            uint16 score = registry.getScore(provider);
            assertLe(score, 1000, "Score exceeds MAX_SCORE");
        }
    }
    
    /// @custom:invariant Counterparty gains never exceed 50 per epoch
    function invariant_CounterpartyGainsNeverExceedCap() public view {
        uint256 providerCount = handler.providersCount();
        uint256 payerCount = handler.payersCount();
        
        for (uint256 i = 0; i < providerCount; i++) {
            address provider = handler.getProvider(i);
            for (uint256 j = 0; j < payerCount; j++) {
                address payer = handler.getPayer(j);
                uint16 gains = registry.getCounterpartyGains(provider, payer);
                assertLe(gains, 50, "Counterparty gains exceed cap");
            }
        }
    }
    
    /// @custom:invariant Epoch is always a multiple of 28 days
    function invariant_EpochIsMultipleOf28Days() public view {
        uint256 epoch = registry.getCurrentEpoch();
        assertEq(epoch % 28 days, 0, "Epoch not multiple of 28 days");
    }
}