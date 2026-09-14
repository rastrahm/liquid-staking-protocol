// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LiquidStakingErrors} from "../errors/LiquidStakingErrors.sol";

/// @title ShareMath
/// @notice WAD / RAY precision helpers for shares ↔ ETH conversions.
/// @dev Uses OZ `Math.mulDiv` (512-bit intermediate) to avoid overflow on large products.
library ShareMath {
    using Math for uint256;

    /// @notice 1e18 fixed-point scale (Wad).
    uint256 internal constant WAD = 1e18;

    /// @notice 1e27 fixed-point scale (Ray).
    uint256 internal constant RAY = 1e27;

    /// @notice Converts pooled ETH amount to shares given pool totals.
    /// @param ethAmount Amount of ETH (wei).
    /// @param totalPooledEther Current total pooled ether.
    /// @param totalShares Current total shares.
    /// @return shares Equivalent share amount (floored).
    function ethToShares(uint256 ethAmount, uint256 totalPooledEther, uint256 totalShares)
        internal
        pure
        returns (uint256 shares)
    {
        if (ethAmount == 0) return 0;
        // Empty pool bootstrap: 1 wei ETH ↔ 1 share.
        if (totalShares == 0) {
            return ethAmount;
        }
        if (totalPooledEther == 0) revert LiquidStakingErrors.MathDivisionByZero();
        return ethAmount.mulDiv(totalShares, totalPooledEther);
    }

    /// @notice Converts shares to pooled ETH amount given pool totals.
    /// @param sharesAmount Amount of shares.
    /// @param totalPooledEther Current total pooled ether.
    /// @param totalShares Current total shares.
    /// @return ethAmount Equivalent ETH (wei, floored).
    function sharesToEth(uint256 sharesAmount, uint256 totalPooledEther, uint256 totalShares)
        internal
        pure
        returns (uint256 ethAmount)
    {
        if (sharesAmount == 0 || totalShares == 0) return 0;
        return sharesAmount.mulDiv(totalPooledEther, totalShares);
    }

    /// @notice Floor division of `a * b / denominator` with 512-bit intermediate product.
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        if (denominator == 0) revert LiquidStakingErrors.MathDivisionByZero();
        return a.mulDiv(b, denominator);
    }

    /// @notice Share rate in RAY: `totalPooledEther * RAY / totalShares`.
    /// @dev Returns 0 if there are no shares yet.
    function shareRateRay(uint256 totalPooledEther, uint256 totalShares) internal pure returns (uint256) {
        if (totalShares == 0) return 0;
        return totalPooledEther.mulDiv(RAY, totalShares);
    }
}
