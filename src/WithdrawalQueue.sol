// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {IWithdrawalQueue} from "./interfaces/IWithdrawalQueue.sol";
import {IStETH} from "./interfaces/IStETH.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title IWithdrawalFinalizer
/// @notice Pool surface used by the queue to burn shares and unlock ETH.
interface IWithdrawalFinalizer {
    /// @notice Burns `sharesAmount` from the queue and sends `ethAmount` ETH to the queue.
    function finalizeWithdrawals(uint256 sharesAmount, uint256 ethAmount) external;
}

/// @title WithdrawalQueue
/// @notice Request-id backed async withdrawal queue for stETH.
contract WithdrawalQueue is IWithdrawalQueue, Ownable2Step, ReentrancyGuardTransient {
    struct WithdrawalRequest {
        address owner;
        uint256 shares;
        uint256 claimableEther;
        uint40 timestamp;
        bool isFinalized;
        bool isClaimed;
    }

    /// @notice Underlying stETH / pool.
    IStETH public immutable stETH;

    /// @notice Optional dedicated finalizer (in addition to owner); typically the accounting oracle.
    address public finalizer;

    uint256 private _lastRequestId;
    uint256 private _lastFinalizedRequestId;

    mapping(uint256 => WithdrawalRequest) private _requests;

    /// @param stETH_ Pool / stETH token.
    /// @param owner_ Admin (can finalize and set finalizer).
    constructor(address stETH_, address owner_) Ownable(owner_) {
        if (stETH_ == address(0) || owner_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        stETH = IStETH(stETH_);
    }

    /// @notice Accepts ETH unlocked by the pool during finalize.
    receive() external payable {}

    /// @notice Sets an additional finalizer address. Only owner.
    function setFinalizer(address finalizer_) external onlyOwner {
        if (finalizer_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        finalizer = finalizer_;
    }

    /// @inheritdoc IWithdrawalQueue
    function getLastRequestId() external view returns (uint256) {
        return _lastRequestId;
    }

    /// @inheritdoc IWithdrawalQueue
    function getLastFinalizedRequestId() external view returns (uint256) {
        return _lastFinalizedRequestId;
    }

    /// @inheritdoc IWithdrawalQueue
    function getWithdrawalStatus(uint256[] calldata requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses)
    {
        statuses = new WithdrawalRequestStatus[](requestIds.length);
        for (uint256 i = 0; i < requestIds.length;) {
            uint256 id = requestIds[i];
            WithdrawalRequest storage req = _requests[id];
            if (req.owner == address(0) && id != 0) revert LiquidStakingErrors.InvalidReport();
            statuses[i] = WithdrawalRequestStatus({
                amountOfStETH: req.claimableEther,
                amountOfShares: req.shares,
                owner: req.owner,
                timestamp: req.timestamp,
                isFinalized: req.isFinalized,
                isClaimed: req.isClaimed
            });
            // Before finalize, surface eth equivalent at current rate for UX.
            if (!req.isFinalized && req.shares > 0) {
                statuses[i].amountOfStETH = stETH.getPooledEthByShares(req.shares);
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function requestWithdrawals(uint256[] calldata amounts, address owner)
        external
        nonReentrant
        returns (uint256[] memory requestIds)
    {
        if (amounts.length == 0) revert LiquidStakingErrors.InvalidReport();
        address recipient = owner == address(0) ? msg.sender : owner;
        if (recipient == address(0)) revert LiquidStakingErrors.ZeroAddress();

        requestIds = new uint256[](amounts.length);

        for (uint256 i = 0; i < amounts.length;) {
            uint256 amount = amounts[i];
            if (amount == 0) revert LiquidStakingErrors.ZeroDeposit();

            uint256 sharesBefore = stETH.sharesOf(address(this));
            bool ok = stETH.transferFrom(msg.sender, address(this), amount);
            if (!ok) revert LiquidStakingErrors.EthTransferFailed();
            uint256 shares = stETH.sharesOf(address(this)) - sharesBefore;
            if (shares == 0) revert LiquidStakingErrors.ZeroDeposit();

            unchecked {
                ++_lastRequestId;
            }
            uint256 requestId = _lastRequestId;

            _requests[requestId] = WithdrawalRequest({
                owner: recipient,
                shares: shares,
                claimableEther: 0,
                timestamp: uint40(block.timestamp),
                isFinalized: false,
                isClaimed: false
            });

            requestIds[i] = requestId;
            emit WithdrawalRequested(requestId, msg.sender, recipient, amount, shares);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IWithdrawalQueue
    function finalize(uint256 lastRequestIdToBeFinalized) external nonReentrant {
        _onlyFinalizer();
        if (lastRequestIdToBeFinalized <= _lastFinalizedRequestId) revert LiquidStakingErrors.InvalidReport();
        if (lastRequestIdToBeFinalized > _lastRequestId) revert LiquidStakingErrors.InvalidReport();

        uint256 fromId = _lastFinalizedRequestId + 1;
        uint256 sharesToBurn;
        uint256 ethToUnlock;

        for (uint256 id = fromId; id <= lastRequestIdToBeFinalized;) {
            WithdrawalRequest storage req = _requests[id];
            if (req.isFinalized) revert LiquidStakingErrors.InvalidReport();
            uint256 claimable = stETH.getPooledEthByShares(req.shares);
            req.claimableEther = claimable;
            req.isFinalized = true;
            sharesToBurn += req.shares;
            ethToUnlock += claimable;
            unchecked {
                ++id;
            }
        }

        if (sharesToBurn == 0 || ethToUnlock == 0) revert LiquidStakingErrors.InvalidReport();

        IWithdrawalFinalizer(address(stETH)).finalizeWithdrawals(sharesToBurn, ethToUnlock);

        _lastFinalizedRequestId = lastRequestIdToBeFinalized;
        emit WithdrawalsFinalized(fromId, lastRequestIdToBeFinalized, ethToUnlock, sharesToBurn);
    }

    /// @inheritdoc IWithdrawalQueue
    function claimWithdrawal(uint256 requestId) external nonReentrant {
        WithdrawalRequest storage req = _requests[requestId];
        if (req.owner == address(0)) revert LiquidStakingErrors.InvalidReport();
        if (!req.isFinalized) revert LiquidStakingErrors.WithdrawalNotFinalized();
        if (req.isClaimed) revert LiquidStakingErrors.WithdrawalAlreadyClaimed();
        if (msg.sender != req.owner) revert LiquidStakingErrors.WithdrawalNotOwner();

        uint256 ethAmount = req.claimableEther;
        // Effects
        req.isClaimed = true;

        (bool ok,) = req.owner.call{value: ethAmount}("");
        if (!ok) revert LiquidStakingErrors.EthTransferFailed();

        emit WithdrawalClaimed(requestId, req.owner, ethAmount);
    }

    function _onlyFinalizer() internal view {
        if (msg.sender != owner() && msg.sender != finalizer) {
            revert LiquidStakingErrors.UnauthorizedOracle();
        }
    }
}
