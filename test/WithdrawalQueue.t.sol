// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {StETH} from "../src/StETH.sol";
import {WithdrawalQueue} from "../src/WithdrawalQueue.sol";
import {IWithdrawalQueue} from "../src/interfaces/IWithdrawalQueue.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";

/// @title WithdrawalQueueTest
/// @notice Lifecycle: request → finalize → claim + auth/error paths.
contract WithdrawalQueueTest is Test {
    StETH internal steth;
    WithdrawalQueue internal queue;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal finalizer = makeAddr("finalizer");

    function setUp() public {
        vm.deal(alice, 1_000 ether);
        vm.deal(bob, 1_000 ether);

        steth = new StETH(owner);
        queue = new WithdrawalQueue(address(steth), owner);

        vm.startPrank(owner);
        steth.setWithdrawalQueue(address(queue));
        queue.setFinalizer(finalizer);
        vm.stopPrank();
    }

    function _submitAndApprove(address user, uint256 amount) internal {
        vm.prank(user);
        steth.submit{value: amount}();
        vm.prank(user);
        steth.approve(address(queue), amount);
    }

    function test_requestFinalizeClaim_lifecycle() public {
        _submitAndApprove(alice, 10 ether);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;

        vm.prank(alice);
        uint256[] memory ids = queue.requestWithdrawals(amounts, address(0));
        assertEq(ids.length, 1);
        assertEq(ids[0], 1);
        assertEq(queue.getLastRequestId(), 1);
        assertEq(steth.sharesOf(address(queue)), 10 ether);
        assertEq(steth.balanceOf(alice), 0);

        uint256 pooledBefore = steth.getTotalPooledEther();

        vm.prank(finalizer);
        queue.finalize(1);

        assertEq(queue.getLastFinalizedRequestId(), 1);
        assertEq(steth.sharesOf(address(queue)), 0);
        assertEq(steth.getBufferedEther(), 0);
        assertEq(steth.getTotalPooledEther(), pooledBefore - 10 ether);
        assertEq(address(queue).balance, 10 ether);

        uint256 aliceEthBefore = alice.balance;
        vm.prank(alice);
        queue.claimWithdrawal(1);
        assertEq(alice.balance, aliceEthBefore + 10 ether);
        assertEq(address(queue).balance, 0);

        IWithdrawalQueue.WithdrawalRequestStatus[] memory statuses;
        uint256[] memory query = new uint256[](1);
        query[0] = 1;
        statuses = queue.getWithdrawalStatus(query);
        assertTrue(statuses[0].isFinalized);
        assertTrue(statuses[0].isClaimed);
        assertEq(statuses[0].owner, alice);
    }

    function test_request_multiple_batchFinalize() public {
        _submitAndApprove(alice, 15 ether);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 10 ether;

        vm.prank(alice);
        uint256[] memory ids = queue.requestWithdrawals(amounts, alice);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);

        vm.prank(owner);
        queue.finalize(2);

        vm.prank(alice);
        queue.claimWithdrawal(1);
        vm.prank(alice);
        queue.claimWithdrawal(2);
        assertEq(address(queue).balance, 0);
    }

    function test_claim_notFinalized_reverts() public {
        _submitAndApprove(alice, 5 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5 ether;
        vm.prank(alice);
        queue.requestWithdrawals(amounts, alice);

        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.WithdrawalNotFinalized.selector);
        queue.claimWithdrawal(1);
    }

    function test_claim_alreadyClaimed_reverts() public {
        _submitAndApprove(alice, 5 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5 ether;
        vm.prank(alice);
        queue.requestWithdrawals(amounts, alice);
        vm.prank(finalizer);
        queue.finalize(1);
        vm.prank(alice);
        queue.claimWithdrawal(1);

        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.WithdrawalAlreadyClaimed.selector);
        queue.claimWithdrawal(1);
    }

    function test_claim_notOwner_reverts() public {
        _submitAndApprove(alice, 5 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5 ether;
        vm.prank(alice);
        queue.requestWithdrawals(amounts, alice);
        vm.prank(finalizer);
        queue.finalize(1);

        vm.prank(bob);
        vm.expectRevert(LiquidStakingErrors.WithdrawalNotOwner.selector);
        queue.claimWithdrawal(1);
    }

    function test_finalize_unauthorized_reverts() public {
        _submitAndApprove(alice, 5 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5 ether;
        vm.prank(alice);
        queue.requestWithdrawals(amounts, alice);

        vm.prank(bob);
        vm.expectRevert(LiquidStakingErrors.UnauthorizedOracle.selector);
        queue.finalize(1);
    }

    function test_finalizeWithdrawals_onlyQueue() public {
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.OnlyWithdrawalQueue.selector);
        steth.finalizeWithdrawals(1, 1);
    }

    function test_claim_afterPositiveRebase_getsMoreEth() public {
        // Alice and bob both deposit; alice requests; rewards accrue; finalize pays current share value.
        vm.prank(alice);
        steth.submit{value: 10 ether}();
        vm.prank(bob);
        steth.submit{value: 10 ether}();

        vm.prank(alice);
        steth.approve(address(queue), 10 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        vm.prank(alice);
        queue.requestWithdrawals(amounts, alice);

        // Positive rebase: add 10 ETH rewards into CL + fund contract for buffer check on finalize.
        // Use oracle-free accounting: increase clBalance via a minimal harness pattern —
        // deal ETH and report through temporarily setting oracle to this test.
        vm.prank(owner);
        steth.setOracle(address(this));
        vm.deal(address(steth), address(steth).balance + 10 ether);
        steth.handleOracleReport(0, 10 ether); // buffer 20→30, fee distributor unset → no fee mint

        // Alice's locked shares are half of supply → claimable ≈ 15 ETH after rebase
        uint256 expected = steth.getPooledEthByShares(steth.sharesOf(address(queue)));
        assertEq(expected, 15 ether);

        vm.prank(finalizer);
        queue.finalize(1);

        uint256 before = alice.balance;
        vm.prank(alice);
        queue.claimWithdrawal(1);
        assertEq(alice.balance - before, 15 ether);
    }

    function testFuzz_requestFinalizeClaim(uint256 amount) public {
        amount = bound(amount, 0.01 ether, 50 ether);
        _submitAndApprove(alice, amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.prank(alice);
        uint256[] memory ids = queue.requestWithdrawals(amounts, alice);

        vm.prank(finalizer);
        queue.finalize(ids[0]);

        uint256 before = alice.balance;
        vm.prank(alice);
        queue.claimWithdrawal(ids[0]);
        assertApproxEqAbs(alice.balance - before, amount, 1);
    }

    // Allow this test contract to act as oracle for the rebase helper above.
    receive() external payable {}
}
