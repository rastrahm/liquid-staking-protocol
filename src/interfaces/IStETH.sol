// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IStETH
/// @notice Minimal rebasing stETH surface (shares-based accounting).
interface IStETH {
    /// @notice Emitted when ETH is submitted to the pool.
    /// @param sender Depositor address.
    /// @param amount ETH amount deposited (wei).
    /// @param referral Optional referral address (may be zero).
    event Submitted(address indexed sender, uint256 amount, address referral);

    /// @notice Emitted on stETH (pooled-ETH denomination) transfers.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted on share transfers.
    event TransferShares(address indexed from, address indexed to, uint256 sharesValue);

    /// @notice Emitted on allowance updates.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Submits ETH and mints shares to the caller.
    /// @return sharesAmount Shares minted.
    function submit() external payable returns (uint256 sharesAmount);

    /// @notice Submits ETH with an optional referral.
    /// @param referral Referral address (informational).
    /// @return sharesAmount Shares minted.
    function submit(address referral) external payable returns (uint256 sharesAmount);

    /// @notice Shares held by `account`.
    function sharesOf(address account) external view returns (uint256);

    /// @notice Total shares in circulation.
    function getTotalShares() external view returns (uint256);

    /// @notice Total pooled ether underlying the share rate.
    function getTotalPooledEther() external view returns (uint256);

    /// @notice Rebasing balance in pooled-ETH units.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Converts an ETH amount to shares at the current rate.
    function getSharesByPooledEth(uint256 ethAmount) external view returns (uint256);

    /// @notice Converts a shares amount to pooled ETH at the current rate.
    function getPooledEthByShares(uint256 sharesAmount) external view returns (uint256);

    /// @notice Transfers `sharesAmount` shares to `to`.
    function transferShares(address to, uint256 sharesAmount) external returns (uint256);

    /// @notice ERC-20 transfer of `amount` in pooled-ETH denomination.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Approves `spender` for `amount` in pooled-ETH denomination.
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Allowance in pooled-ETH denomination.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice ERC-20 transferFrom in pooled-ETH denomination.
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
}
