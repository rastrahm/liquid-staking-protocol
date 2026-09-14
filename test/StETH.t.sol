// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IStETH} from "../src/interfaces/IStETH.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";
import {StETHHarness} from "./helpers/Harnesses.sol";

/// @title StETHTest
/// @notice Deposit-to-share minting under varying pool share rates.
contract StETHTest is Test {
    StETHHarness internal steth;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        steth = new StETHHarness();
        vm.deal(alice, 1_000 ether);
        vm.deal(bob, 1_000 ether);
    }

    function test_metadata() public view {
        assertEq(steth.name(), "Liquid staked Ether");
        assertEq(steth.symbol(), "stETH");
        assertEq(steth.decimals(), 18);
    }

    function test_remapping_IERC20() public pure {
        assertEq(bytes4(IERC20.transfer.selector), bytes4(keccak256("transfer(address,uint256)")));
    }

    function test_submit_firstDeposit_oneToOne() public {
        vm.prank(alice);
        uint256 shares = steth.submit{value: 10 ether}();

        assertEq(shares, 10 ether);
        assertEq(steth.sharesOf(alice), 10 ether);
        assertEq(steth.balanceOf(alice), 10 ether);
        assertEq(steth.getTotalShares(), 10 ether);
        assertEq(steth.getTotalPooledEther(), 10 ether);
        assertEq(steth.totalSupply(), 10 ether);
        assertEq(address(steth).balance, 10 ether);
    }

    function test_submit_withReferral_emitsSubmitted() public {
        address referral = makeAddr("referral");
        vm.expectEmit(true, true, true, true);
        emit IStETH.Submitted(alice, 1 ether, referral);
        vm.prank(alice);
        steth.submit{value: 1 ether}(referral);
    }

    function test_receive_eth_mintsShares() public {
        vm.prank(alice);
        (bool ok,) = address(steth).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(steth.sharesOf(alice), 2 ether);
        assertEq(steth.balanceOf(alice), 2 ether);
    }

    function test_submit_zeroValue_reverts() public {
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.ZeroDeposit.selector);
        steth.submit{value: 0}();
    }

    function test_submit_afterPositiveRebase_mintsFewerShares() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        // Simulate +10 ETH rewards → rate 2 ETH/share.
        steth.simulateRewards(10 ether);
        assertEq(steth.getTotalPooledEther(), 20 ether);
        assertEq(steth.balanceOf(alice), 20 ether);
        assertEq(steth.sharesOf(alice), 10 ether); // shares unchanged

        vm.prank(bob);
        uint256 bobShares = steth.submit{value: 10 ether}();

        // 10 ETH at rate 2 → 5 shares
        assertEq(bobShares, 5 ether);
        assertEq(steth.sharesOf(bob), 5 ether);
        assertEq(steth.balanceOf(bob), 10 ether);
        assertEq(steth.getTotalShares(), 15 ether);
        assertEq(steth.getTotalPooledEther(), 30 ether);
        // Alice still 10 shares → 10/15 * 30 = 20
        assertEq(steth.balanceOf(alice), 20 ether);
    }

    function test_submit_afterNegativeRebase_mintsMoreShares() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        // Loss of 4 ETH → pooled 6 with 10 shares (rate 0.6).
        steth.simulateLoss(4 ether);

        assertEq(steth.getTotalPooledEther(), 6 ether);
        assertEq(steth.balanceOf(alice), 6 ether);

        vm.prank(bob);
        uint256 bobShares = steth.submit{value: 6 ether}();
        // 6 ETH into pool with 6 ETH / 10 shares → 10 shares
        assertEq(bobShares, 10 ether);
        assertEq(steth.sharesOf(bob), 10 ether);
        assertEq(steth.getTotalPooledEther(), 12 ether);
        assertEq(steth.balanceOf(bob), 6 ether);
    }

    function test_transfer_movesRebasingBalance() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(alice);
        bool ok = steth.transfer(bob, 4 ether);
        assertTrue(ok);
        assertEq(steth.balanceOf(alice), 6 ether);
        assertEq(steth.balanceOf(bob), 4 ether);
        assertEq(steth.sharesOf(alice) + steth.sharesOf(bob), steth.getTotalShares());
    }

    function test_transferShares() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();

        vm.prank(alice);
        steth.transferShares(bob, 3 ether);
        assertEq(steth.sharesOf(bob), 3 ether);
        assertEq(steth.sharesOf(alice), 7 ether);
    }

    function test_approve_and_transferFrom() public {
        vm.prank(alice);
        steth.submit{value: 5 ether}();

        vm.prank(alice);
        steth.approve(bob, 2 ether);

        vm.prank(bob);
        steth.transferFrom(alice, bob, 2 ether);

        assertEq(steth.balanceOf(bob), 2 ether);
        assertEq(steth.allowance(alice, bob), 0);
    }

    function test_transferFrom_insufficientAllowance_reverts() public {
        vm.prank(alice);
        steth.submit{value: 5 ether}();
        vm.prank(bob);
        vm.expectRevert(LiquidStakingErrors.InsufficientBalance.selector);
        steth.transferFrom(alice, bob, 1 ether);
    }

    function test_transfer_insufficientShares_reverts() public {
        vm.prank(alice);
        steth.submit{value: 1 ether}();
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.InsufficientBalance.selector);
        steth.transfer(bob, 2 ether);
    }

    function testFuzz_submit_firstDepositor(uint256 amount) public {
        amount = bound(amount, 1, 500 ether);
        vm.deal(alice, amount);
        vm.prank(alice);
        uint256 shares = steth.submit{value: amount}();
        assertEq(shares, amount);
        assertEq(steth.balanceOf(alice), amount);
        assertEq(steth.getSharesByPooledEth(amount), amount);
    }

    function testFuzz_submit_afterRateChange(uint256 firstDeposit, uint256 rewards, uint256 secondDeposit) public {
        firstDeposit = bound(firstDeposit, 1 ether, 100 ether);
        rewards = bound(rewards, 0, 100 ether);
        secondDeposit = bound(secondDeposit, 1 ether, 100 ether);

        vm.deal(alice, firstDeposit);
        vm.deal(bob, secondDeposit);

        vm.prank(alice);
        uint256 aliceShares = steth.submit{value: firstDeposit}();
        steth.simulateRewards(rewards);

        uint256 pooledBefore = steth.getTotalPooledEther();
        uint256 expectedBobShares = steth.getSharesByPooledEth(secondDeposit);

        vm.prank(bob);
        uint256 bobShares = steth.submit{value: secondDeposit}();

        assertEq(bobShares, expectedBobShares);
        assertEq(steth.sharesOf(alice), aliceShares);
        assertEq(steth.getTotalShares(), aliceShares + bobShares);
        assertEq(steth.getTotalPooledEther(), pooledBefore + secondDeposit);

        // Sum of balances ≈ total pooled (dust from flooring allowed per holder)
        uint256 sumBalances = steth.balanceOf(alice) + steth.balanceOf(bob);
        assertLe(sumBalances, steth.getTotalPooledEther());
        assertGe(sumBalances + 2, steth.getTotalPooledEther()); // at most 1 wei dust per holder
    }

    function testFuzz_getSharesByPooledEth_matchesSubmit(uint256 amount) public {
        // Min 1 gwei so shares minted are non-zero at rate 1.5 (10+5 pooled / 10 shares).
        amount = bound(amount, 1e9, 50 ether);
        // Seed pool at rate ≠ 1
        vm.prank(alice);
        steth.submit{value: 10 ether}();
        steth.simulateRewards(5 ether);

        uint256 predicted = steth.getSharesByPooledEth(amount);
        assertGt(predicted, 0);
        vm.deal(bob, amount);
        vm.prank(bob);
        uint256 minted = steth.submit{value: amount}();
        assertEq(minted, predicted);
    }
}
