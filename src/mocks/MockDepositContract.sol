// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IDepositContract} from "../interfaces/IDepositContract.sol";
import {LiquidStakingErrors} from "../errors/LiquidStakingErrors.sol";

/// @title MockDepositContract
/// @notice Minimal Eth2 deposit contract mock for Foundry tests.
contract MockDepositContract is IDepositContract {
    uint256 public depositCount;
    uint256 public totalDeposited;

    /// @dev Last deposit snapshot for assertions.
    bytes public lastPubkey;
    bytes public lastWithdrawalCredentials;
    bytes public lastSignature;
    bytes32 public lastDepositDataRoot;

    /// @inheritdoc IDepositContract
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable {
        if (msg.value != 32 ether) revert LiquidStakingErrors.InvalidReport();
        if (pubkey.length != 48) revert LiquidStakingErrors.InvalidReport();
        if (withdrawal_credentials.length != 32) revert LiquidStakingErrors.InvalidReport();
        if (signature.length != 96) revert LiquidStakingErrors.InvalidReport();

        unchecked {
            depositCount += 1;
            totalDeposited += msg.value;
        }

        lastPubkey = pubkey;
        lastWithdrawalCredentials = withdrawal_credentials;
        lastSignature = signature;
        lastDepositDataRoot = deposit_data_root;

        emit DepositEvent(pubkey, withdrawal_credentials, abi.encodePacked(uint64(32 ether / 1 gwei)), signature, _to_little_endian_64(uint64(depositCount)));
    }

    /// @inheritdoc IDepositContract
    function get_deposit_root() external pure returns (bytes32) {
        return bytes32(0);
    }

    /// @inheritdoc IDepositContract
    function get_deposit_count() external view returns (bytes memory) {
        return _to_little_endian_64(uint64(depositCount));
    }

    function _to_little_endian_64(uint64 value) private pure returns (bytes memory ret) {
        ret = new bytes(8);
        bytes8 bytesValue = bytes8(value);
        for (uint256 i = 0; i < 8; ++i) {
            ret[i] = bytesValue[7 - i];
        }
    }
}
