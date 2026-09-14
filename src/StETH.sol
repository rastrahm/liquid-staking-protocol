// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IStETH} from "./interfaces/IStETH.sol";
import {ILiquidStakingPool} from "./interfaces/ILiquidStakingPool.sol";
import {FeeDistributor} from "./FeeDistributor.sol";
import {ShareMath} from "./libraries/ShareMath.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title StETH
/// @notice Shares-based rebasing liquid staking token (stETH-style).
/// @dev Pooled ether = bufferedEther + clBalance. Oracle reports update CL/EL accounting.
contract StETH is IStETH, ILiquidStakingPool, Ownable2Step, ReentrancyGuardTransient {
    /// @notice Emitted after an authorized oracle accounting report.
    /// @param clBalance New consensus-layer balance.
    /// @param elRewards Execution-layer rewards credited.
    /// @param preTotalPooledEther Pooled ether before the report.
    /// @param postTotalPooledEther Pooled ether after the report (before fee share mint dilution effect on rate).
    event OracleReported(
        uint256 clBalance, uint256 elRewards, uint256 preTotalPooledEther, uint256 postTotalPooledEther
    );

    /// @notice Emitted when protocol fee shares are minted on a positive rebase.
    event FeeMinted(
        address indexed treasury,
        address indexed nodeOperators,
        uint256 treasuryShares,
        uint256 operatorShares,
        uint256 feeEther
    );

    /// @dev Shares held by each account.
    mapping(address => uint256) private _shares;

    /// @dev ERC-20 allowances in pooled-ETH denomination.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @dev Total shares outstanding.
    uint256 private _totalShares;

    /// @dev ETH held in the protocol buffer (not yet deposited to validators).
    uint256 internal bufferedEther;

    /// @dev Consensus-layer balance accounted by oracle.
    uint256 internal clBalance;

    /// @notice Authorized oracle contract (typically `AccountingOracle`).
    address public oracle;

    /// @notice Fee split configuration (optional until set).
    FeeDistributor public feeDistributor;

    /// @notice Last time `handleOracleReport` succeeded.
    uint256 public lastReportTimestamp;

    /// @param owner_ Admin for oracle / fee distributor wiring.
    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
    }

    /// @notice Sets the authorized oracle. Only owner.
    /// @param oracle_ Accounting oracle address.
    function setOracle(address oracle_) external onlyOwner {
        if (oracle_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        oracle = oracle_;
    }

    /// @notice Sets the fee distributor. Only owner.
    /// @param feeDistributor_ FeeDistributor address.
    function setFeeDistributor(address feeDistributor_) external onlyOwner {
        if (feeDistributor_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        feeDistributor = FeeDistributor(feeDistributor_);
    }

    /// @notice Current consensus-layer balance from the last report.
    function getClBalance() external view returns (uint256) {
        return clBalance;
    }

    /// @notice Current buffered ether awaiting validator deposit.
    function getBufferedEther() external view returns (uint256) {
        return bufferedEther;
    }

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
    function allowance(address owner_, address spender) external view returns (uint256) {
        return _allowances[owner_][spender];
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

    /// @inheritdoc ILiquidStakingPool
    function handleOracleReport(uint256 newClBalance, uint256 elRewards) external nonReentrant {
        if (msg.sender != oracle) revert LiquidStakingErrors.UnauthorizedOracle();

        uint256 preTotal = _getTotalPooledEther();

        if (elRewards > 0) {
            // EL rewards must already be present (or transferred) as ETH in the contract buffer.
            if (address(this).balance < bufferedEther + elRewards) {
                revert LiquidStakingErrors.InvalidReport();
            }
            bufferedEther += elRewards;
        }

        clBalance = newClBalance;

        uint256 postTotal = _getTotalPooledEther();
        lastReportTimestamp = block.timestamp;

        if (postTotal == 0 && _totalShares > 0) revert LiquidStakingErrors.NegativeRebaseBlocked();

        if (postTotal > preTotal && _totalShares > 0) {
            uint256 reward = postTotal - preTotal;
            _collectProtocolFee(reward, postTotal);
        }

        emit OracleReported(newClBalance, elRewards, preTotal, postTotal);
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

    /// @dev Hook for total pooled ether.
    function _getTotalPooledEther() internal view virtual returns (uint256) {
        return bufferedEther + clBalance;
    }

    /// @dev Mints fee shares so recipients own `feeEther` of the post-reward pool.
    function _collectProtocolFee(uint256 reward, uint256 postTotal) internal {
        FeeDistributor fees = feeDistributor;
        if (address(fees) == address(0)) return;

        uint256 feeEther = fees.feeOnReward(reward);
        if (feeEther == 0) return;
        if (feeEther >= postTotal) revert LiquidStakingErrors.InvalidReport();

        // shares = totalShares * feeEther / (postTotal - feeEther)
        uint256 sharesToMint = ShareMath.mulDiv(_totalShares, feeEther, postTotal - feeEther);
        if (sharesToMint == 0) return;

        (uint256 treasuryShares, uint256 operatorShares) = fees.splitShares(sharesToMint);
        address treasury = fees.treasury();
        address operators = fees.nodeOperators();

        if (treasuryShares > 0) _mintShares(treasury, treasuryShares);
        if (operatorShares > 0) _mintShares(operators, operatorShares);

        emit FeeMinted(treasury, operators, treasuryShares, operatorShares, feeEther);
    }

    /// @dev CEI: mint shares and update buffer before any external interaction (none here).
    function _submit(address recipient, address referral) internal nonReentrant returns (uint256 sharesAmount) {
        uint256 deposit = msg.value;
        if (deposit == 0) revert LiquidStakingErrors.ZeroDeposit();
        if (recipient == address(0)) revert LiquidStakingErrors.ZeroAddress();

        sharesAmount = getSharesByPooledEth(deposit);
        if (sharesAmount == 0) revert LiquidStakingErrors.ZeroDeposit();

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

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert LiquidStakingErrors.ZeroAddress();
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
}
