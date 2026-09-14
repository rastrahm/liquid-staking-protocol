// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {StETHHarness} from "../helpers/Harnesses.sol";
import {WithdrawalQueue} from "../../src/WithdrawalQueue.sol";
import {LiquidStakingHandler} from "./LiquidStakingHandler.sol";

/// @title PoolSolvencyInvariantTest
/// @notice Share conservation + liquid ETH backs buffered ether.
contract PoolSolvencyInvariantTest is StdInvariant, Test {
    StETHHarness internal steth;
    WithdrawalQueue internal queue;
    LiquidStakingHandler internal handler;

    address internal owner;

    function setUp() public {
        steth = new StETHHarness();
        owner = steth.owner();
        queue = new WithdrawalQueue(address(steth), owner);

        vm.startPrank(owner);
        steth.setWithdrawalQueue(address(queue));
        queue.setFinalizer(owner);
        vm.stopPrank();

        handler = new LiquidStakingHandler(steth, queue, owner);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = LiquidStakingHandler.submit.selector;
        selectors[1] = LiquidStakingHandler.slash.selector;
        selectors[2] = LiquidStakingHandler.reward.selector;
        selectors[3] = LiquidStakingHandler.transfer.selector;
        selectors[4] = LiquidStakingHandler.requestWithdraw.selector;
        selectors[5] = LiquidStakingHandler.finalizeAndClaim.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @notice All tracked holders' shares sum to `totalShares` (actors + queue).
    function invariant_SharesConserved() public view {
        assertEq(handler.sumShares(), steth.getTotalShares());
    }

    /// @notice Liquid ETH in the pool covers the buffer accounting commitment.
    function invariant_BufferSolvency() public view {
        assertGe(address(steth).balance, steth.getBufferedEther());
    }

    /// @notice Floored balances of tracked holders never exceed total pooled ether.
    function invariant_BalancesBoundedByPooled() public view {
        assertLe(handler.sumBalances(), steth.getTotalPooledEther());
    }

    /// @notice If shares exist, pooled ether must be non-zero (no soft-lock at zero rate).
    function invariant_NonZeroPooledWhenShares() public view {
        if (steth.getTotalShares() > 0) {
            assertGt(steth.getTotalPooledEther(), 0);
        }
    }
}
