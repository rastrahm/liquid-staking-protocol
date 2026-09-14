// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAccountingOracle
/// @notice Authorized committee that pushes CL/EL accounting reports into the pool.
interface IAccountingOracle {
    /// @notice Emitted when a report is accepted and forwarded to the pool.
    event ReportSubmitted(address indexed member, uint256 clBalance, uint256 elRewards, uint256 timestamp);

    /// @notice Emitted when a committee member is added.
    event MemberAdded(address indexed member);

    /// @notice Emitted when a committee member is removed.
    event MemberRemoved(address indexed member);

    /// @notice Pool that receives `handleOracleReport`.
    function pool() external view returns (address);

    /// @notice Minimum seconds between accepted reports.
    function reportInterval() external view returns (uint256);

    /// @notice Timestamp of the last accepted report.
    function lastReportTimestamp() external view returns (uint256);

    /// @notice Whether `account` is a committee member.
    function members(address account) external view returns (bool);

    /// @notice Number of committee members.
    function memberCount() external view returns (uint256);

    /// @notice Submits a balance report (only committee members).
    /// @param clBalance New consensus-layer total balance (wei).
    /// @param elRewards Execution-layer rewards to credit to the buffer (wei).
    function submitReport(uint256 clBalance, uint256 elRewards) external;
}
