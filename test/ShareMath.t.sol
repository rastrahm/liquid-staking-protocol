// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";
import {ShareMathHarness} from "./helpers/Harnesses.sol";

/// @title ShareMathTest
/// @notice Unit + fuzz for shares ↔ ETH conversions.
contract ShareMathTest is Test {
    ShareMathHarness internal math;

    function setUp() public {
        math = new ShareMathHarness();
    }

    function test_constants() public view {
        assertEq(math.wad(), 1e18);
        assertEq(math.ray(), 1e27);
    }

    function test_ethToShares_emptyPool_oneToOne() public view {
        assertEq(math.ethToShares(1 ether, 0, 0), 1 ether);
        assertEq(math.ethToShares(3 ether, 0, 0), 3 ether);
    }

    function test_ethToShares_zeroAmount() public view {
        assertEq(math.ethToShares(0, 100 ether, 50 ether), 0);
    }

    function test_ethToShares_rateNotOne() public view {
        // Pool: 100 ETH / 50 shares → rate 2. Deposit 10 ETH → 5 shares.
        assertEq(math.ethToShares(10 ether, 100 ether, 50 ether), 5 ether);
    }

    function test_sharesToEth_emptyShares() public view {
        assertEq(math.sharesToEth(1 ether, 10 ether, 0), 0);
    }

    function test_sharesToEth_rateNotOne() public view {
        assertEq(math.sharesToEth(5 ether, 100 ether, 50 ether), 10 ether);
    }

    function test_roundTrip_atRateTwo() public view {
        uint256 ethAmount = 5 ether;
        uint256 totalEth = 100 ether;
        uint256 totalShares = 50 ether;
        uint256 shares = math.ethToShares(ethAmount, totalEth, totalShares);
        uint256 back = math.sharesToEth(shares, totalEth, totalShares);
        assertEq(shares, 2.5 ether);
        assertEq(back, ethAmount);
    }

    function test_shareRateRay() public view {
        assertEq(math.shareRateRay(0, 0), 0);
        // 2 ETH per share → 2e27 RAY
        assertEq(math.shareRateRay(100 ether, 50 ether), 2e27);
    }

    function test_mulDiv_revertsOnZeroDenominator() public {
        vm.expectRevert(LiquidStakingErrors.MathDivisionByZero.selector);
        math.mulDiv(1, 1, 0);
    }

    function test_ethToShares_revertsWhenSharesExistButPooledZero() public {
        vm.expectRevert(LiquidStakingErrors.MathDivisionByZero.selector);
        math.ethToShares(1 ether, 0, 1);
    }

    function testFuzz_ethToShares_emptyPool(uint256 ethAmount) public view {
        ethAmount = bound(ethAmount, 0, type(uint128).max);
        assertEq(math.ethToShares(ethAmount, 0, 0), ethAmount);
    }

    function testFuzz_roundTrip_floor(uint256 ethAmount, uint256 totalEth, uint256 totalShares) public view {
        totalShares = bound(totalShares, 1, type(uint128).max);
        totalEth = bound(totalEth, 1, type(uint128).max);
        ethAmount = bound(ethAmount, 0, totalEth);

        uint256 shares = math.ethToShares(ethAmount, totalEth, totalShares);
        uint256 back = math.sharesToEth(shares, totalEth, totalShares);
        // Flooring: converting to shares and back never exceeds the original ETH amount.
        assertLe(back, ethAmount);
        // Idempotence on the shares side: sharesToEth → ethToShares recovers <= shares.
        assertLe(math.ethToShares(back, totalEth, totalShares), shares);
    }

    function testFuzz_mulDiv(uint256 a, uint256 b) public view {
        a = bound(a, 0, type(uint128).max);
        b = bound(b, 0, type(uint128).max);
        assertEq(math.mulDiv(a, b, 1), a * b);
    }
}
