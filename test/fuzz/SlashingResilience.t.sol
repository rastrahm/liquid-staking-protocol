// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ShareMath} from "../../src/libraries/ShareMath.sol";
import {WithdrawalQueue} from "../../src/WithdrawalQueue.sol";
import {StETHHarness} from "../helpers/Harnesses.sol";

/// @title SlashingResilienceTest
/// @notice Fuzz negative yield: converters stay safe; users keep a withdraw path when buffer allows.
contract SlashingResilienceTest is Test {
    StETHHarness internal steth;
    WithdrawalQueue internal queue;

    address internal owner;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        steth = new StETHHarness();
        owner = steth.owner();
        queue = new WithdrawalQueue(address(steth), owner);

        vm.startPrank(owner);
        steth.setWithdrawalQueue(address(queue));
        queue.setFinalizer(owner);
        vm.stopPrank();

        vm.deal(alice, 10_000 ether);
        vm.deal(bob, 10_000 ether);
    }

    function testFuzz_slash_shareConvertersNoOverflow(uint256 deposit, uint256 lossBps) public {
        deposit = bound(deposit, 1 ether, type(uint128).max / 4);
        lossBps = bound(lossBps, 0, 9_999);

        uint256 totalShares = deposit;
        uint256 totalEth = deposit;
        uint256 loss = (totalEth * lossBps) / 10_000;
        totalEth -= loss;

        uint256 mid = deposit / 3;
        uint256 shares = ShareMath.ethToShares(mid, totalEth, totalShares);
        uint256 back = ShareMath.sharesToEth(shares, totalEth, totalShares);
        assertLe(back, mid);

        uint256 oneShareEth = ShareMath.sharesToEth(1, totalEth, totalShares);
        if (loss > 0) {
            assertLe(ShareMath.sharesToEth(totalShares, totalEth, totalShares), deposit);
            assertLe(oneShareEth, 1 ether);
        }
    }

    function testFuzz_slash_userCanStillSubmitAndWithdraw(uint256 deposit, uint256 loss, uint256 withdrawAmt)
        public
    {
        deposit = bound(deposit, 2 ether, 200 ether);
        // Keep enough buffer after loss for a meaningful withdraw path.
        loss = bound(loss, 0, deposit / 2);
        withdrawAmt = bound(withdrawAmt, 0.01 ether, deposit - loss);

        vm.prank(alice);
        steth.submit{value: deposit}();

        if (loss > 0) {
            steth.simulateLoss(loss);
        }

        uint256 pooled = steth.getTotalPooledEther();
        assertGt(pooled, 0);
        assertEq(steth.sharesOf(alice), deposit); // shares unchanged on slash

        // Converter views must not revert.
        uint256 sharesForOne = steth.getSharesByPooledEth(1 ether);
        uint256 ethForShares = steth.getPooledEthByShares(steth.sharesOf(alice));
        assertLe(ethForShares, pooled);
        if (pooled >= 1 ether) {
            assertGt(sharesForOne, 0);
        }

        // Bob can still join after negative rebase.
        uint256 bobIn = bound(withdrawAmt, 0.01 ether, 50 ether);
        vm.prank(bob);
        uint256 bobShares = steth.submit{value: bobIn}();
        assertGt(bobShares, 0);

        // Alice withdraws via queue using remaining buffer liquidity.
        uint256 aliceBal = steth.balanceOf(alice);
        uint256 toWithdraw = bound(withdrawAmt, 0.01 ether, aliceBal);
        uint256 buffer = steth.getBufferedEther();
        if (toWithdraw > buffer) {
            toWithdraw = buffer;
        }
        if (toWithdraw == 0) return;

        vm.startPrank(alice);
        steth.approve(address(queue), toWithdraw);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = toWithdraw;
        uint256[] memory ids = queue.requestWithdrawals(amounts, alice);
        vm.stopPrank();

        // Finalize requires buffer ETH; after request shares moved but buffer unchanged until finalize.
        vm.prank(owner);
        queue.finalize(ids[0]);

        uint256 before = alice.balance;
        vm.prank(alice);
        queue.claimWithdrawal(ids[0]);
        assertGt(alice.balance, before);
    }

    function testFuzz_slash_neverLocksAllSharesWithoutEthPath(uint256 deposit, uint256 lossBps) public {
        deposit = bound(deposit, 1 ether, 100 ether);
        lossBps = bound(lossBps, 1, 9_999);

        vm.prank(alice);
        steth.submit{value: deposit}();

        uint256 loss = (deposit * lossBps) / 10_000;
        if (loss == 0) loss = 1;
        if (loss >= deposit) loss = deposit - 1; // leave >= 1 wei pooled

        steth.simulateLoss(loss);

        assertGt(steth.getTotalPooledEther(), 0);
        assertEq(steth.getTotalShares(), deposit);
        assertGt(steth.balanceOf(alice), 0);

        // Transfer still works after slash (no lock).
        uint256 halfShares = steth.sharesOf(alice) / 2;
        if (halfShares == 0) return;
        vm.prank(alice);
        steth.transferShares(bob, halfShares);
        assertEq(steth.sharesOf(bob), halfShares);
    }

    function testFuzz_ethToShares_afterSlash_matchesPool(uint256 deposit, uint256 loss, uint256 add)
        public
    {
        deposit = bound(deposit, 1 ether, 100 ether);
        loss = bound(loss, 0, deposit - 1);
        add = bound(add, 1e9, 50 ether);

        vm.prank(alice);
        steth.submit{value: deposit}();
        steth.simulateLoss(loss);

        uint256 predicted = steth.getSharesByPooledEth(add);
        assertGt(predicted, 0);

        vm.prank(bob);
        uint256 minted = steth.submit{value: add}();
        assertEq(minted, predicted);
    }

    function test_slash_toZeroWithShares_viaOraclePath_blocked() public {
        // Oracle report to zero CL with zero buffer is blocked on StETH (not harness).
        // Covered in OracleReport; here ensure harness loss cannot zero with shares unpaid path:
        vm.prank(alice);
        steth.submit{value: 10 ether}();
        vm.expectRevert(); // simulateLoss require
        steth.simulateLoss(11 ether);
    }
}
