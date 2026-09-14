// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAccountingOracle} from "./interfaces/IAccountingOracle.sol";
import {ILiquidStakingPool} from "./interfaces/ILiquidStakingPool.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title AccountingOracle
/// @notice Committee-gated reporter for validator CL balances and EL rewards.
contract AccountingOracle is IAccountingOracle, Ownable2Step {
    /// @inheritdoc IAccountingOracle
    address public immutable override pool;

    /// @inheritdoc IAccountingOracle
    uint256 public immutable override reportInterval;

    /// @inheritdoc IAccountingOracle
    uint256 public override lastReportTimestamp;

    /// @inheritdoc IAccountingOracle
    mapping(address => bool) public override members;

    /// @inheritdoc IAccountingOracle
    uint256 public override memberCount;

    /// @param pool_ Liquid staking pool / stETH address.
    /// @param reportInterval_ Minimum seconds between reports.
    /// @param initialMember First authorized committee member.
    /// @param owner_ Admin that can add/remove members.
    constructor(address pool_, uint256 reportInterval_, address initialMember, address owner_) Ownable(owner_) {
        if (pool_ == address(0) || initialMember == address(0) || owner_ == address(0)) {
            revert LiquidStakingErrors.ZeroAddress();
        }
        pool = pool_;
        reportInterval = reportInterval_;
        _addMember(initialMember);
    }

    /// @inheritdoc IAccountingOracle
    function submitReport(uint256 clBalance, uint256 elRewards) external {
        if (!members[msg.sender]) revert LiquidStakingErrors.UnauthorizedOracle();
        if (lastReportTimestamp != 0 && block.timestamp < lastReportTimestamp + reportInterval) {
            revert LiquidStakingErrors.ReportTooEarly();
        }

        lastReportTimestamp = block.timestamp;
        ILiquidStakingPool(pool).handleOracleReport(clBalance, elRewards);

        emit ReportSubmitted(msg.sender, clBalance, elRewards, block.timestamp);
    }

    /// @notice Adds a committee member. Only owner.
    function addMember(address member) external onlyOwner {
        _addMember(member);
    }

    /// @notice Removes a committee member. Only owner.
    function removeMember(address member) external onlyOwner {
        if (member == address(0)) revert LiquidStakingErrors.ZeroAddress();
        if (!members[member]) revert LiquidStakingErrors.InvalidReport();
        if (memberCount <= 1) revert LiquidStakingErrors.InvalidReport();
        members[member] = false;
        unchecked {
            memberCount -= 1;
        }
        emit MemberRemoved(member);
    }

    function _addMember(address member) internal {
        if (member == address(0)) revert LiquidStakingErrors.ZeroAddress();
        if (members[member]) revert LiquidStakingErrors.InvalidReport();
        members[member] = true;
        unchecked {
            memberCount += 1;
        }
        emit MemberAdded(member);
    }
}
