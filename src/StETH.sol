// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IStETH} from "./interfaces/IStETH.sol";
import {ShareMath} from "./libraries/ShareMath.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title StETH
/// @notice Shares-based rebasing liquid staking token (stETH-style).
/// @dev Fase 1: buffer-only pooled ether. Consensus layer balance arrives in later phases.
contract StETH is IStETH, ReentrancyGuardTransient {
    /// @dev Shares held by each account.
    mapping(address => uint256) private _shares;

    /// @dev ERC-20 allowances in pooled-ETH denomination.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @dev Total shares outstanding.
    uint256 private _totalShares;

    /// @dev ETH held in the protocol buffer (not yet deposited to validators).
    uint256 internal bufferedEther;

    /// @dev Consensus-layer balance accounted by oracle (0 until Fase 3/4).
    uint256 internal clBalance;

    /// @inheritdoc IStETH
    function name() external pure returns (string memory) {
        return "Liquid staked Ether";
    }

    /// @inheritdoc IStETH
    function symbol() external pure returns (string memory) {
        return "stETH";
    }

    /// @inheritdoc IStETH
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @inheritdoc IStETH
    function totalSupply() external view returns (uint256) {
        return getTotalPooledEther();
    }

    /// @inheritdoc IStETH
    function getTotalShares() public view returns (uint256) {
        return _totalShares;
    }

    /// @inheritdoc IStETH
    function getTotalPooledEther() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    /// @inheritdoc IStETH
    function sharesOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    /// @inheritdoc IStETH
    function balanceOf(address account) public view returns (uint256) {
        return getPooledEthByShares(_shares[account]);
    }

    /// @inheritdoc IStETH
    function getSharesByPooledEth(uint256 ethAmount) public view returns (uint256) {
        return ShareMath.ethToShares(ethAmount, _getTotalPooledEther(), _totalShares);
    }

    /// @inheritdoc IStETH
    function getPooledEthByShares(uint256 sharesAmount) public view returns (uint256) {
        return ShareMath.sharesToEth(sharesAmount, _getTotalPooledEther(), _totalShares);
    }

    /// @inheritdoc IStETH
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @inheritdoc IStETH
    function submit() external payable returns (uint256) {
        return _submit(msg.sender, address(0));
    }

    /// @inheritdoc IStETH
    function submit(address referral) external payable returns (uint256) {
        return _submit(msg.sender, referral);
    }

    /// @notice Accepts plain ETH transfers as deposits.
    receive() external payable {
        _submit(msg.sender, address(0));
    }

    /// @inheritdoc IStETH
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IStETH
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @inheritdoc IStETH
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance < amount) revert LiquidStakingErrors.InsufficientBalance();
        unchecked {
            _approve(from, msg.sender, currentAllowance - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    /// @inheritdoc IStETH
    function transferShares(address to, uint256 sharesAmount) external returns (uint256) {
        _transferShares(msg.sender, to, sharesAmount);
        emit Transfer(msg.sender, to, getPooledEthByShares(sharesAmount));
        emit TransferShares(msg.sender, to, sharesAmount);
        return sharesAmount;
    }

    /// @dev Hook for total pooled ether. Override in tests / future pool to add external balances.
    function _getTotalPooledEther() internal view virtual returns (uint256) {
        return bufferedEther + clBalance;
    }

    /// @dev CEI: mint shares and update buffer before any external interaction (none here).
    function _submit(address recipient, address referral) internal nonReentrant returns (uint256 sharesAmount) {
        uint256 deposit = msg.value;
        if (deposit == 0) revert LiquidStakingErrors.ZeroDeposit();
        if (recipient == address(0)) revert LiquidStakingErrors.ZeroAddress();

        sharesAmount = getSharesByPooledEth(deposit);
        if (sharesAmount == 0) revert LiquidStakingErrors.ZeroDeposit();

        // Effects
        bufferedEther += deposit;
        _mintShares(recipient, sharesAmount);

        emit Submitted(recipient, deposit, referral);
        emit Transfer(address(0), recipient, getPooledEthByShares(sharesAmount));
        emit TransferShares(address(0), recipient, sharesAmount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        uint256 sharesToTransfer = getSharesByPooledEth(amount);
        if (sharesToTransfer == 0 && amount != 0) revert LiquidStakingErrors.ZeroDeposit();
        _transferShares(from, to, sharesToTransfer);
        emit Transfer(from, to, amount);
        emit TransferShares(from, to, sharesToTransfer);
    }

    function _transferShares(address from, address to, uint256 sharesAmount) internal {
        if (to == address(0)) revert LiquidStakingErrors.ZeroAddress();
        if (sharesAmount == 0) revert LiquidStakingErrors.ZeroDeposit();
        uint256 fromShares = _shares[from];
        if (fromShares < sharesAmount) revert LiquidStakingErrors.InsufficientBalance();
        unchecked {
            _shares[from] = fromShares - sharesAmount;
        }
        _shares[to] += sharesAmount;
    }

    function _mintShares(address account, uint256 sharesAmount) internal {
        if (account == address(0)) revert LiquidStakingErrors.ZeroAddress();
        _totalShares += sharesAmount;
        _shares[account] += sharesAmount;
    }

    function _burnShares(address account, uint256 sharesAmount) internal {
        uint256 accountShares = _shares[account];
        if (accountShares < sharesAmount) revert LiquidStakingErrors.InsufficientBalance();
        unchecked {
            _shares[account] = accountShares - sharesAmount;
            _totalShares -= sharesAmount;
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert LiquidStakingErrors.ZeroAddress();
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
