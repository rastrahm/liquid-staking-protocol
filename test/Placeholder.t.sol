// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Placeholder} from "../src/Placeholder.sol";
import {ShareMath} from "../src/libraries/ShareMath.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";

/// @title PlaceholderTest
/// @notice Fase 0 smoke: compile path, remappings OZ, ShareMath stubs, error selectors.
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_ping() public view {
        assertEq(placeholder.ping(), 1);
    }

    function test_remapping_IERC20_interface() public pure {
        // Ensures @openzeppelin remapping resolves at compile time.
        assertEq(bytes4(IERC20.transfer.selector), bytes4(keccak256("transfer(address,uint256)")));
    }

    function test_shareMath_constants() public pure {
        assertEq(ShareMath.WAD, 1e18);
        assertEq(ShareMath.RAY, 1e27);
    }

    function test_shareMath_ethToShares_emptyPool_isOneToOne() public pure {
        assertEq(ShareMath.ethToShares(1 ether, 0, 0), 1 ether);
    }

    function test_shareMath_sharesToEth_emptyShares_isZero() public pure {
        assertEq(ShareMath.sharesToEth(1 ether, 10 ether, 0), 0);
    }

    function test_shareMath_roundTrip_stubRatio() public pure {
        uint256 ethAmount = 5 ether;
        uint256 totalEth = 100 ether;
        uint256 totalShares = 50 ether;
        uint256 shares = ShareMath.ethToShares(ethAmount, totalEth, totalShares);
        uint256 back = ShareMath.sharesToEth(shares, totalEth, totalShares);
        assertEq(shares, 2.5 ether);
        assertEq(back, ethAmount);
    }

    function test_unauthorizedOracle_selector() public pure {
        assertEq(
            LiquidStakingErrors.UnauthorizedOracle.selector,
            bytes4(keccak256("UnauthorizedOracle()"))
        );
    }

    function testFuzz_pingAlwaysOne(uint256) public view {
        assertEq(placeholder.ping(), 1);
    }
}
