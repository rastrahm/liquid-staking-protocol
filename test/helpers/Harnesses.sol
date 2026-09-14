// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ShareMath} from "../../src/libraries/ShareMath.sol";
import {StETH} from "../../src/StETH.sol";

/// @title ShareMathHarness
/// @notice Exposes ShareMath for unit tests.
contract ShareMathHarness {
    function ethToShares(uint256 ethAmount, uint256 totalPooledEther, uint256 totalShares)
        external
        pure
        returns (uint256)
    {
        return ShareMath.ethToShares(ethAmount, totalPooledEther, totalShares);
    }

    function sharesToEth(uint256 sharesAmount, uint256 totalPooledEther, uint256 totalShares)
        external
        pure
        returns (uint256)
    {
        return ShareMath.sharesToEth(sharesAmount, totalPooledEther, totalShares);
    }

    function mulDiv(uint256 a, uint256 b, uint256 denominator) external pure returns (uint256) {
        return ShareMath.mulDiv(a, b, denominator);
    }

    function shareRateRay(uint256 totalPooledEther, uint256 totalShares) external pure returns (uint256) {
        return ShareMath.shareRateRay(totalPooledEther, totalShares);
    }

    function wad() external pure returns (uint256) {
        return ShareMath.WAD;
    }

    function ray() external pure returns (uint256) {
        return ShareMath.RAY;
    }
}

/// @title StETHHarness
/// @notice Allows simulating CL rewards / slash without oracle (Fase 1 tests).
contract StETHHarness is StETH {
    constructor() StETH(msg.sender) {}

    /// @notice Increases consensus-layer balance to simulate positive rebase.
    function simulateRewards(uint256 amount) external {
        clBalance += amount;
    }

    /// @notice Decreases consensus-layer balance to simulate slashing.
    function simulateSlash(uint256 amount) external {
        clBalance -= amount;
    }

    /// @notice Reduces total pooled ether (CL first, then buffer) to simulate losses.
    function simulateLoss(uint256 amount) external {
        uint256 pooled = _getTotalPooledEther();
        require(amount <= pooled, "loss > pooled");
        if (amount <= clBalance) {
            clBalance -= amount;
            return;
        }
        uint256 remaining = amount - clBalance;
        clBalance = 0;
        bufferedEther -= remaining;
    }

    /// @notice Moves buffer into CL accounting (simulates validator deposit for lab tests).
    function moveBufferToCl() external {
        clBalance += bufferedEther;
        bufferedEther = 0;
    }

    /// @notice Sets CL balance absolutely (lab only).
    function setClBalance(uint256 amount) external {
        clBalance = amount;
    }
}
