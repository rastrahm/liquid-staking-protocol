// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ILiquidStakingPool
/// @notice Oracle-facing pool surface for accounting reports.
interface ILiquidStakingPool {
    /// @notice Applies a consensus/execution accounting update.
    /// @param clBalance New total consensus-layer balance (wei).
    /// @param elRewards Execution-layer rewards credited to the buffer (wei).
    function handleOracleReport(uint256 clBalance, uint256 elRewards) external;
}
