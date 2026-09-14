// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IWstETH
/// @notice Value-accruing wrapper around rebasing stETH (1 wstETH = 1 stETH share).
interface IWstETH {
    /// @notice Emitted when stETH is wrapped into wstETH.
    event Wrapped(address indexed account, uint256 stETHAmount, uint256 wstETHAmount);

    /// @notice Emitted when wstETH is unwrapped into stETH.
    event Unwrapped(address indexed account, uint256 wstETHAmount, uint256 stETHAmount);

    /// @notice Underlying stETH token.
    function stETH() external view returns (address);

    /// @notice Wraps `stETHAmount` of stETH into wstETH (share-denominated).
    /// @param stETHAmount Amount of stETH (pooled-ETH units) to wrap.
    /// @return wstETHAmount Shares / wstETH minted.
    function wrap(uint256 stETHAmount) external returns (uint256 wstETHAmount);

    /// @notice Unwraps `wstETHAmount` into stETH.
    /// @param wstETHAmount Amount of wstETH (shares) to burn.
    /// @return stETHAmount Pooled-ETH units returned.
    function unwrap(uint256 wstETHAmount) external returns (uint256 stETHAmount);

    /// @notice How much stETH one wstETH is worth at the current rate.
    function stEthPerToken() external view returns (uint256);

    /// @notice How much wstETH one stETH wraps into at the current rate.
    function tokensPerStEth() external view returns (uint256);

    /// @notice Converts a stETH amount to wstETH at the current rate.
    function getWstETHByStETH(uint256 stETHAmount) external view returns (uint256);

    /// @notice Converts a wstETH amount to stETH at the current rate.
    function getStETHByWstETH(uint256 wstETHAmount) external view returns (uint256);
}
