// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {StETHHarness} from "../helpers/Harnesses.sol";
import {WithdrawalQueue} from "../../src/WithdrawalQueue.sol";
import {IWithdrawalQueue} from "../../src/interfaces/IWithdrawalQueue.sol";

/// @title LiquidStakingHandler
/// @notice Ghost-aware handler for pool solvency / share-sum invariants.
contract LiquidStakingHandler is Test {
    StETHHarness public immutable steth;
    WithdrawalQueue public immutable queue;
    address public immutable owner;

    address[] public actorsList;

    constructor(StETHHarness steth_, WithdrawalQueue queue_, address owner_) {
        steth = steth_;
        queue = queue_;
        owner = owner_;

        actorsList.push(makeAddr("actor0"));
        actorsList.push(makeAddr("actor1"));
        actorsList.push(makeAddr("actor2"));

        for (uint256 i = 0; i < actorsList.length; ++i) {
            vm.deal(actorsList[i], 1_000_000 ether);
        }
    }

    function actors() external view returns (address[] memory) {
        return actorsList;
    }

    /// @notice Submit ETH → mint shares.
    function submit(uint256 actorSeed, uint256 amount) external {
        address actor = actorsList[actorSeed % actorsList.length];
        amount = bound(amount, 0.01 ether, 50 ether);
        if (actor.balance < amount) return;

        vm.prank(actor);
        steth.submit{value: amount}();
    }

    /// @notice Simulate consensus/buffer loss without wiping the pool to zero.
    function slash(uint256 amount) external {
        uint256 pooled = steth.getTotalPooledEther();
        if (pooled <= 1) return;
        amount = bound(amount, 1, pooled - 1);
        steth.simulateLoss(amount);
    }

    /// @notice Simulate positive CL rewards (fund ETH so contract balance stays coherent).
    function reward(uint256 amount) external {
        amount = bound(amount, 1, 20 ether);
        vm.deal(address(steth), address(steth).balance + amount);
        steth.simulateRewards(amount);
    }

    /// @notice Transfer stETH between actors.
    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actorsList[fromSeed % actorsList.length];
        address to = actorsList[toSeed % actorsList.length];
        if (from == to) return;
        uint256 bal = steth.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        vm.prank(from);
        try steth.transfer(to, amount) {} catch {}
    }

    /// @notice Request withdrawal of some balance into the queue.
    function requestWithdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actorsList[actorSeed % actorsList.length];
        uint256 bal = steth.balanceOf(actor);
        if (bal < 0.01 ether) return;
        amount = bound(amount, 0.01 ether, bal);

        if (steth.getBufferedEther() < amount) return;

        vm.startPrank(actor);
        steth.approve(address(queue), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        try queue.requestWithdrawals(amounts, actor) {} catch {}
        vm.stopPrank();
    }

    /// @notice Finalize next request and claim if buffer liquidity allows.
    function finalizeAndClaim() external {
        uint256 last = queue.getLastRequestId();
        uint256 lastFin = queue.getLastFinalizedRequestId();
        if (last == 0 || lastFin >= last) return;

        uint256 nextId = lastFin + 1;
        uint256[] memory ids = new uint256[](1);
        ids[0] = nextId;
        IWithdrawalQueue.WithdrawalRequestStatus memory st = queue.getWithdrawalStatus(ids)[0];
        if (st.owner == address(0) || st.amountOfShares == 0) return;

        uint256 need = steth.getPooledEthByShares(st.amountOfShares);
        if (need == 0 || steth.getBufferedEther() < need) return;
        if (address(steth).balance < need) return;

        vm.prank(owner);
        try queue.finalize(nextId) {
            ids[0] = nextId;
            st = queue.getWithdrawalStatus(ids)[0];
            vm.prank(st.owner);
            try queue.claimWithdrawal(nextId) {} catch {}
        } catch {}
    }

    function sumShares() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actorsList.length; ++i) {
            sum += steth.sharesOf(actorsList[i]);
        }
        sum += steth.sharesOf(address(queue));
    }

    function sumBalances() external view returns (uint256 sum) {
        for (uint256 i = 0; i < actorsList.length; ++i) {
            sum += steth.balanceOf(actorsList[i]);
        }
        sum += steth.balanceOf(address(queue));
    }
}
