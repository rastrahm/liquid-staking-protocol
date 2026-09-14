// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IStETH} from "./interfaces/IStETH.sol";
import {IWstETH} from "./interfaces/IWstETH.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title WstETH
/// @notice Non-rebasing ERC-20 wrapper: 1 wstETH represents 1 stETH share.
/// @dev User `balanceOf(wstETH)` stays fixed across rebases; `stEthPerToken()` accrues value.
contract WstETH is IWstETH, ERC20, ReentrancyGuardTransient {
    /// @dev Underlying rebasing stETH.
    IStETH private immutable _stETH;

    /// @param stETH_ Address of the stETH token.
    constructor(address stETH_) ERC20("Wrapped liquid staked Ether", "wstETH") {
        if (stETH_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        _stETH = IStETH(stETH_);
    }

    /// @inheritdoc IWstETH
    function stETH() public view returns (address) {
        return address(_stETH);
    }

    /// @notice Wraps msg.value ETH by submitting to stETH then minting wstETH shares.
    receive() external payable nonReentrant {
        uint256 shares = _stETH.submit{value: msg.value}();
        if (shares == 0) revert LiquidStakingErrors.ZeroDeposit();
        _mint(msg.sender, shares);
        emit Wrapped(msg.sender, msg.value, shares);
    }

    /// @inheritdoc IWstETH
    function wrap(uint256 stETHAmount) external nonReentrant returns (uint256 wstETHAmount) {
        if (stETHAmount == 0) revert LiquidStakingErrors.ZeroDeposit();

        wstETHAmount = _stETH.getSharesByPooledEth(stETHAmount);
        if (wstETHAmount == 0) revert LiquidStakingErrors.ZeroDeposit();

        bool ok = _stETH.transferFrom(msg.sender, address(this), stETHAmount);
        if (!ok) revert LiquidStakingErrors.EthTransferFailed();

        _mint(msg.sender, wstETHAmount);
        emit Wrapped(msg.sender, stETHAmount, wstETHAmount);
    }

    /// @inheritdoc IWstETH
    function unwrap(uint256 wstETHAmount) external nonReentrant returns (uint256 stETHAmount) {
        if (wstETHAmount == 0) revert LiquidStakingErrors.ZeroDeposit();
        if (balanceOf(msg.sender) < wstETHAmount) revert LiquidStakingErrors.InsufficientBalance();

        stETHAmount = _stETH.getPooledEthByShares(wstETHAmount);
        if (stETHAmount == 0) revert LiquidStakingErrors.ZeroDeposit();

        _burn(msg.sender, wstETHAmount);

        bool ok = _stETH.transfer(msg.sender, stETHAmount);
        if (!ok) revert LiquidStakingErrors.EthTransferFailed();

        emit Unwrapped(msg.sender, wstETHAmount, stETHAmount);
    }

    /// @inheritdoc IWstETH
    function stEthPerToken() external view returns (uint256) {
        return _stETH.getPooledEthByShares(1 ether);
    }

    /// @inheritdoc IWstETH
    function tokensPerStEth() external view returns (uint256) {
        return _stETH.getSharesByPooledEth(1 ether);
    }

    /// @inheritdoc IWstETH
    function getWstETHByStETH(uint256 stETHAmount) external view returns (uint256) {
        return _stETH.getSharesByPooledEth(stETHAmount);
    }

    /// @inheritdoc IWstETH
    function getStETHByWstETH(uint256 wstETHAmount) external view returns (uint256) {
        return _stETH.getPooledEthByShares(wstETHAmount);
    }
}
