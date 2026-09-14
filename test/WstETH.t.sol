// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {WstETH} from "../src/WstETH.sol";
import {IWstETH} from "../src/interfaces/IWstETH.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";
import {StETHHarness} from "./helpers/Harnesses.sol";

/// @title WstETHTest
/// @notice Wrap/unwrap parity and non-rebasing balance behaviour.
contract WstETHTest is Test {
    StETHHarness internal steth;
    WstETH internal wsteth;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        steth = new StETHHarness();
        wsteth = new WstETH(address(steth));
        vm.deal(alice, 1_000 ether);
        vm.deal(bob, 1_000 ether);
    }

    function test_metadata() public view {
        assertEq(wsteth.name(), "Wrapped liquid staked Ether");
        assertEq(wsteth.symbol(), "wstETH");
        assertEq(wsteth.decimals(), 18);
        assertEq(wsteth.stETH(), address(steth));
    }

    function test_constructor_zeroAddress_reverts() public {
        vm.expectRevert(LiquidStakingErrors.ZeroAddress.selector);
        new WstETH(address(0));
    }

    function test_wrap_unwrap_parity_atRateOne() public {
        vm.startPrank(alice);
        steth.submit{value: 10 ether}();
        steth.approve(address(wsteth), 10 ether);

        uint256 wst = wsteth.wrap(10 ether);
        assertEq(wst, 10 ether);
        assertEq(wsteth.balanceOf(alice), 10 ether);
        assertEq(steth.balanceOf(alice), 0);
        assertEq(steth.balanceOf(address(wsteth)), 10 ether);

        uint256 stOut = wsteth.unwrap(10 ether);
        assertEq(stOut, 10 ether);
        assertEq(wsteth.balanceOf(alice), 0);
        assertEq(steth.balanceOf(alice), 10 ether);
        vm.stopPrank();
    }

    function test_wrap_emitsWrapped() public {
        vm.startPrank(alice);
        steth.submit{value: 1 ether}();
        steth.approve(address(wsteth), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit IWstETH.Wrapped(alice, 1 ether, 1 ether);
        wsteth.wrap(1 ether);
        vm.stopPrank();
    }

    function test_unwrap_emitsUnwrapped() public {
        vm.startPrank(alice);
        steth.submit{value: 1 ether}();
        steth.approve(address(wsteth), 1 ether);
        wsteth.wrap(1 ether);

        vm.expectEmit(true, true, true, true);
        emit IWstETH.Unwrapped(alice, 1 ether, 1 ether);
        wsteth.unwrap(1 ether);
        vm.stopPrank();
    }

    function test_wrap_zero_reverts() public {
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.ZeroDeposit.selector);
        wsteth.wrap(0);
    }

    function test_unwrap_zero_reverts() public {
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.ZeroDeposit.selector);
        wsteth.unwrap(0);
    }

    function test_unwrap_insufficientBalance_reverts() public {
        vm.prank(alice);
        vm.expectRevert(LiquidStakingErrors.InsufficientBalance.selector);
        wsteth.unwrap(1 ether);
    }

    function test_postRebase_wstethBalanceUnchanged_stEthPerTokenIncreases() public {
        vm.startPrank(alice);
        steth.submit{value: 10 ether}();
        steth.approve(address(wsteth), 10 ether);
        uint256 wst = wsteth.wrap(10 ether);
        vm.stopPrank();

        uint256 rateBefore = wsteth.stEthPerToken();
        assertEq(rateBefore, 1 ether);
        assertEq(wsteth.balanceOf(alice), wst);

        // Positive rebase: stETH held by wrapper grows in value; wstETH balance does not.
        steth.simulateRewards(10 ether);

        assertEq(wsteth.balanceOf(alice), wst); // non-rebasing
        assertEq(wsteth.stEthPerToken(), 2 ether);
        assertEq(wsteth.getStETHByWstETH(wst), 20 ether);
        assertEq(steth.balanceOf(address(wsteth)), 20 ether);

        vm.prank(alice);
        uint256 stOut = wsteth.unwrap(wst);
        assertEq(stOut, 20 ether);
        assertEq(steth.balanceOf(alice), 20 ether);
    }

    function test_wrap_afterPositiveRebase_mintsFewerWstETH() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();
        steth.simulateRewards(10 ether); // rate 2

        vm.startPrank(bob);
        steth.submit{value: 10 ether}(); // 5 shares
        steth.approve(address(wsteth), 10 ether);
        uint256 wst = wsteth.wrap(10 ether);
        assertEq(wst, 5 ether);
        assertEq(wsteth.tokensPerStEth(), 0.5 ether);
        assertEq(wsteth.getWstETHByStETH(10 ether), 5 ether);
        vm.stopPrank();
    }

    function test_receive_eth_wrapsViaSubmit() public {
        vm.prank(alice);
        (bool ok,) = address(wsteth).call{value: 3 ether}("");
        assertTrue(ok);
        assertEq(wsteth.balanceOf(alice), 3 ether);
        assertEq(steth.balanceOf(address(wsteth)), 3 ether);
    }

    function test_views_matchStETHConverters() public {
        vm.prank(alice);
        steth.submit{value: 10 ether}();
        steth.simulateRewards(5 ether);

        assertEq(wsteth.stEthPerToken(), steth.getPooledEthByShares(1 ether));
        assertEq(wsteth.tokensPerStEth(), steth.getSharesByPooledEth(1 ether));
        assertEq(wsteth.getWstETHByStETH(3 ether), steth.getSharesByPooledEth(3 ether));
        assertEq(wsteth.getStETHByWstETH(2 ether), steth.getPooledEthByShares(2 ether));
    }

    function testFuzz_wrapUnwrap_parity(uint256 amount) public {
        amount = bound(amount, 1e9, 100 ether);

        vm.startPrank(alice);
        steth.submit{value: amount}();
        steth.approve(address(wsteth), amount);

        uint256 wst = wsteth.wrap(amount);
        assertEq(wst, steth.getSharesByPooledEth(amount)); // before wrap amount left alice; use wst identity
        // After wrap, 1 wstETH = 1 share; unwrap should return floor-equivalent stETH
        uint256 expectedSt = steth.getPooledEthByShares(wst);
        uint256 stOut = wsteth.unwrap(wst);
        assertEq(stOut, expectedSt);
        // Dust: recovered stETH within 1 wei per share of original (flooring)
        assertLe(stOut, amount);
        assertGe(stOut + 1, amount > 0 ? amount : 0); // typically equal at rate 1
        assertEq(stOut, amount); // rate 1 → exact
        vm.stopPrank();
    }

    function testFuzz_wrapUnwrap_afterRebase(uint256 deposit, uint256 rewards) public {
        deposit = bound(deposit, 1 ether, 50 ether);
        rewards = bound(rewards, 0, 50 ether);

        vm.startPrank(alice);
        steth.submit{value: deposit}();
        steth.approve(address(wsteth), deposit);
        uint256 wst = wsteth.wrap(deposit);
        uint256 wstBalanceBefore = wsteth.balanceOf(alice);
        vm.stopPrank();

        steth.simulateRewards(rewards);

        assertEq(wsteth.balanceOf(alice), wstBalanceBefore);

        uint256 expectedSt = wsteth.getStETHByWstETH(wst);
        vm.prank(alice);
        uint256 stOut = wsteth.unwrap(wst);
        assertEq(stOut, expectedSt);
        assertEq(stOut, deposit + rewards); // sole wrapper holder accrues full rewards
    }

    function testFuzz_stEthPerToken_nonRebasingSupply(uint256 deposit, uint256 rewards) public {
        deposit = bound(deposit, 1 ether, 50 ether);
        // Rewards large enough to move stEthPerToken by at least 1 wei: need rewards * 1e18 / deposit >= 1
        rewards = bound(rewards, deposit / 1 ether, 50 ether); // >= 1 wei per stEthPerToken unit when deposit in ether

        vm.startPrank(alice);
        steth.submit{value: deposit}();
        steth.approve(address(wsteth), deposit);
        uint256 wst = wsteth.wrap(deposit);
        vm.stopPrank();

        uint256 supplyBefore = wsteth.totalSupply();
        uint256 balBefore = wsteth.balanceOf(alice);
        uint256 valueBefore = wsteth.getStETHByWstETH(wst);

        steth.simulateRewards(rewards);

        assertEq(wsteth.totalSupply(), supplyBefore);
        assertEq(wsteth.balanceOf(alice), balBefore);
        assertEq(wsteth.getStETHByWstETH(wst), valueBefore + rewards);
        assertGe(wsteth.stEthPerToken(), 1 ether);
    }
}
