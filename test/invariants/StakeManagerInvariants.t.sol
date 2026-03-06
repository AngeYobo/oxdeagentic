// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StakeManager} from "../../src/StakeManager.sol";
import {IStakeManager} from "../../src/interfaces/IStakeManager.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockInsurancePool} from "../mocks/MockInsurancePool.sol";

contract StakeManagerHandler is Test {
    StakeManager public stakeManager;
    MockERC20 public token;
    address public escrow;

    address[] public providersList;
    mapping(address => bool) public isProvider;

    uint256 public ghostTotalDeposits;
    uint256 public ghostTotalWithdrawals;
    uint256 public ghostTotalSlashed;
    uint256 public ghostLockCount;

    constructor(StakeManager _stakeManager, MockERC20 _token, address _escrow) {
        stakeManager = _stakeManager;
        token = _token;
        escrow = _escrow;
    }

    // Add helper functions for array access
    function providersCount() external view returns (uint256) {
        return providersList.length;
    }

    function getProvider(uint256 index) external view returns (address) {
        return providersList[index];
    }

    function depositStake(uint8 providerSeed, uint96 amount) public {
        amount = uint96(bound(amount, 1 ether, 100 ether));

        address provider = address(uint160(providerSeed) + 100);

        if (!isProvider[provider]) {
            providersList.push(provider);
            isProvider[provider] = true;
            token.mint(provider, 1000 ether);
            vm.prank(provider);
            token.approve(address(stakeManager), type(uint256).max);
        }

        vm.prank(provider);
        stakeManager.depositStake(address(token), amount);

        ghostTotalDeposits += amount;
    }

    function withdrawStake(uint8 providerSeed, uint96 amount) public {
        if (providersList.length == 0) return;

        address provider = providersList[providerSeed % providersList.length];
        uint256 available = stakeManager.availableStake(provider, address(token));

        if (available == 0) return;

        amount = uint96(bound(amount, 1, available));

        vm.prank(provider);
        stakeManager.withdrawStake(address(token), amount);

        ghostTotalWithdrawals += amount;
    }

    function lockStake(uint8 providerSeed, uint96 amount, bytes32 intentId) public {
        if (providersList.length == 0) return;

        address provider = providersList[providerSeed % providersList.length];
        uint256 available = stakeManager.availableStake(provider, address(token));

        if (available == 0) return;

        amount = uint96(bound(amount, 1, available));

        vm.prank(escrow);
        try stakeManager.lockStake(provider, address(token), amount, intentId) {
            ghostLockCount++;
        } catch {}
    }

    function unlockStake(bytes32 intentId) public {
        vm.prank(escrow);
        stakeManager.unlockStake(intentId);
    }

    function slash(bytes32 intentId, uint96 amount) public {
        IStakeManager.StakeLock memory lock = stakeManager.intentLocks(intentId);

        if (!lock.active || lock.amount == 0) return;

        uint256 maxSlash = (uint256(lock.amount) * 5000) / 10_000;
        amount = uint96(bound(amount, 1, maxSlash));

        vm.prank(escrow);
        try stakeManager.slash(intentId, amount) {
            ghostTotalSlashed += amount;
        } catch {}
    }
}

contract StakeManagerInvariantsTest is Test {
    StakeManager public stakeManager;
    MockERC20 public token;
    MockInsurancePool public insurancePool;
    StakeManagerHandler public handler;

    address public escrow = address(0xE5C);

    function setUp() public {
        token = new MockERC20("Test", "TEST", 18);
        insurancePool = new MockInsurancePool();
        stakeManager = new StakeManager(escrow, address(insurancePool));

        handler = new StakeManagerHandler(stakeManager, token, escrow);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = StakeManagerHandler.depositStake.selector;
        selectors[1] = StakeManagerHandler.withdrawStake.selector;
        selectors[2] = StakeManagerHandler.lockStake.selector;
        selectors[3] = StakeManagerHandler.unlockStake.selector;
        selectors[4] = StakeManagerHandler.slash.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @custom:invariant Total stake = locked + available (always)
    function invariant_TotalEqualsLockedPlusAvailable() public view {
        uint256 providerCount = handler.providersCount();
        for (uint256 i = 0; i < providerCount; i++) {
            address provider = handler.getProvider(i);

            uint256 total = stakeManager.totalStake(provider, address(token));
            uint256 locked = stakeManager.lockedStake(provider, address(token));
            uint256 available = stakeManager.availableStake(provider, address(token));

            assertEq(total, locked + available, "Total != locked + available");
        }
    }

    /// @custom:invariant Locked stake never exceeds total stake
    function invariant_LockedNeverExceedsTotal() public view {
        uint256 providerCount = handler.providersCount();
        for (uint256 i = 0; i < providerCount; i++) {
            address provider = handler.getProvider(i);

            uint256 total = stakeManager.totalStake(provider, address(token));
            uint256 locked = stakeManager.lockedStake(provider, address(token));

            assertLe(locked, total, "Locked exceeds total");
        }
    }

    /// @custom:invariant Contract token balance >= sum of all provider stakes
    function invariant_ContractBalanceSufficient() public view {
        uint256 contractBalance = token.balanceOf(address(stakeManager));
        uint256 sumStakes = 0;

        uint256 providerCount = handler.providersCount();
        for (uint256 i = 0; i < providerCount; i++) {
            address provider = handler.getProvider(i);
            sumStakes += stakeManager.totalStake(provider, address(token));
        }

        assertGe(contractBalance, sumStakes, "Contract balance insufficient");
    }

    /// @custom:invariant Accounting matches ghost variables
    function invariant_AccountingConsistent() public view {
        uint256 netDeposits = handler.ghostTotalDeposits() - handler.ghostTotalWithdrawals();
        uint256 expectedInContract = netDeposits - handler.ghostTotalSlashed();
        uint256 actualInContract = token.balanceOf(address(stakeManager));

        assertEq(actualInContract, expectedInContract, "Accounting mismatch");
    }
}
