// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LiquidStakingErrors} from "../errors/LiquidStakingErrors.sol";

/// @title ShareMath
/// @notice WAD / RAY precision helpers for shares ↔ ETH conversions.
/// @dev Fase 0: constants + stubs. Full `ethToShares` / `sharesToEth` in Fase 1.
library ShareMath {
    /// @notice 1e18 fixed-point scale (Wad).
    uint256 internal constant WAD = 1e18;

    /// @notice 1e27 fixed-point scale (Ray).
    uint256 internal constant RAY = 1e27;

    /// @notice Converts pooled ETH amount to shares given pool totals.
    /// @dev Stub — implemented in Fase 1.
    /// @param ethAmount Amount of ETH (wei).
    /// @param totalPooledEther Current total pooled ether.
    /// @param totalShares Current total shares.
    /// @return shares Equivalent share amount.
    function ethToShares(uint256 ethAmount, uint256 totalPooledEther, uint256 totalShares)
        internal
        pure
        returns (uint256 shares)
    {
        // Fase 0 stub: 1:1 when empty pool; otherwise deferred to Fase 1 logic.
        if (totalShares == 0 || totalPooledEther == 0) {
            return ethAmount;
        }
        return (ethAmount * totalShares) / totalPooledEther;
    }

    /// @notice Converts shares to pooled ETH amount given pool totals.
    /// @dev Stub — rounding / edge cases hardened in Fase 1.
    /// @param sharesAmount Amount of shares.
    /// @param totalPooledEther Current total pooled ether.
    /// @param totalShares Current total shares.
    /// @return ethAmount Equivalent ETH (wei).
    function sharesToEth(uint256 sharesAmount, uint256 totalPooledEther, uint256 totalShares)
        internal
        pure
        returns (uint256 ethAmount)
    {
        if (totalShares == 0) {
            return 0;
        }
        return (sharesAmount * totalPooledEther) / totalShares;
    }

    /// @notice Floor division of `a * b / denominator` without intermediate overflow when possible.
    /// @dev Minimal stub; prefer FullMath-style in Fase 1 if needed for large products.
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        if (denominator == 0) revert LiquidStakingErrors.MathDivisionByZero();
        return (a * b) / denominator;
    }
}
