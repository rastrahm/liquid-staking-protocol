// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IWithdrawalQueue
/// @notice Asynchronous stETH withdrawal requests (request → finalize → claim).
interface IWithdrawalQueue {
    /// @notice Withdrawal request status view.
    struct WithdrawalRequestStatus {
        uint256 amountOfStETH;
        uint256 amountOfShares;
        address owner;
        uint256 timestamp;
        bool isFinalized;
        bool isClaimed;
    }

    event WithdrawalRequested(
        uint256 indexed requestId, address indexed requestor, address indexed owner, uint256 amountOfStETH, uint256 shares
    );
    event WithdrawalsFinalized(uint256 fromRequestId, uint256 toRequestId, uint256 ethLocked, uint256 sharesBurned);
    event WithdrawalClaimed(uint256 indexed requestId, address indexed owner, uint256 ethAmount);

    /// @notice Creates withdrawal requests by locking stETH shares.
    /// @param amounts stETH amounts (pooled-ETH units) to withdraw.
    /// @param owner Recipient of the claim rights (zero → msg.sender).
    /// @return requestIds Created request ids.
    function requestWithdrawals(uint256[] calldata amounts, address owner)
        external
        returns (uint256[] memory requestIds);

    /// @notice Finalizes requests up to `lastRequestIdToBeFinalized` (burns shares, locks ETH).
    function finalize(uint256 lastRequestIdToBeFinalized) external;

    /// @notice Claims ETH for a finalized request.
    function claimWithdrawal(uint256 requestId) external;

    /// @notice Last created request id.
    function getLastRequestId() external view returns (uint256);

    /// @notice Last finalized request id.
    function getLastFinalizedRequestId() external view returns (uint256);

    /// @notice Status of the given request ids.
    function getWithdrawalStatus(uint256[] calldata requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses);
}
