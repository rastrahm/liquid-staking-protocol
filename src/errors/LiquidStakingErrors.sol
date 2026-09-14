// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LiquidStakingErrors
/// @notice Custom errors for the liquid staking protocol (módulo 18).
library LiquidStakingErrors {
    /// @notice Caller is not an authorized oracle committee member / reporter.
    error UnauthorizedOracle();

    /// @notice `msg.value` is zero on submit.
    error ZeroDeposit();

    /// @notice Insufficient ETH, shares, or token balance for the operation.
    error InsufficientBalance();

    /// @notice Oracle report data is inconsistent or malformed.
    error InvalidReport();

    /// @notice Report submitted before the minimum interval / invalid ref slot.
    error ReportTooEarly();

    /// @notice Negative rebase would break pool solvency invariants.
    error NegativeRebaseBlocked();

    /// @notice Withdrawal request has not been finalized yet.
    error WithdrawalNotFinalized();

    /// @notice Withdrawal request was already claimed.
    error WithdrawalAlreadyClaimed();

    /// @notice Caller is not the owner of the withdrawal request.
    error WithdrawalNotOwner();

    /// @notice Protocol fee exceeds the immutable cap.
    error FeeCapExceeded();

    /// @notice Native ETH transfer via `.call` failed.
    error EthTransferFailed();

    /// @notice Address argument is the zero address.
    error ZeroAddress();

    /// @notice Protocol is paused.
    error Paused();

    /// @notice No signing keys available for validator deposits.
    error NoSigningKeys();

    /// @notice Division by zero in ShareMath.
    error MathDivisionByZero();

    /// @notice Caller is not the staking pool.
    error OnlyPool();

    /// @notice Caller is not the withdrawal queue.
    error OnlyWithdrawalQueue();
}
