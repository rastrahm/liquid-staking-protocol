// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title FeeDistributor
/// @notice Immutable-capped protocol fee split between treasury and node operators.
contract FeeDistributor {
    /// @notice Absolute maximum protocol fee on rewards (10%).
    uint16 public constant MAX_PROTOCOL_FEE_BPS = 1000;

    /// @notice Protocol fee taken from positive oracle rewards (bps of reward).
    uint16 public immutable protocolFeeBps;

    /// @notice Share of protocol fee shares minted to treasury (bps of fee shares).
    uint16 public immutable treasuryShareBps;

    /// @notice Treasury recipient of fee shares.
    address public immutable treasury;

    /// @notice Node operators recipient of remaining fee shares.
    address public immutable nodeOperators;

    /// @param protocolFeeBps_ Fee on rewards in bps (≤ MAX_PROTOCOL_FEE_BPS).
    /// @param treasury_ Treasury address.
    /// @param nodeOperators_ Node operators reward address.
    /// @param treasuryShareBps_ Portion of fee shares to treasury (≤ 10_000).
    constructor(uint16 protocolFeeBps_, address treasury_, address nodeOperators_, uint16 treasuryShareBps_) {
        if (protocolFeeBps_ > MAX_PROTOCOL_FEE_BPS) revert LiquidStakingErrors.FeeCapExceeded();
        if (treasury_ == address(0) || nodeOperators_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        if (treasuryShareBps_ > 10_000) revert LiquidStakingErrors.FeeCapExceeded();

        protocolFeeBps = protocolFeeBps_;
        treasury = treasury_;
        nodeOperators = nodeOperators_;
        treasuryShareBps = treasuryShareBps_;
    }

    /// @notice Fee ether taken from a positive reward amount.
    /// @param reward Gross positive rebase amount (wei).
    /// @return feeEther Protocol fee in wei.
    function feeOnReward(uint256 reward) public view returns (uint256 feeEther) {
        return (reward * uint256(protocolFeeBps)) / 10_000;
    }

    /// @notice Splits fee shares between treasury and node operators.
    /// @param feeShares Total shares minted as protocol fee.
    /// @return treasuryShares Shares for treasury.
    /// @return operatorShares Shares for node operators.
    function splitShares(uint256 feeShares)
        public
        view
        returns (uint256 treasuryShares, uint256 operatorShares)
    {
        treasuryShares = (feeShares * uint256(treasuryShareBps)) / 10_000;
        operatorShares = feeShares - treasuryShares;
    }
}
