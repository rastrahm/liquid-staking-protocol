// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IDepositContract
/// @notice Ethereum 2.0 deposit contract interface (mainnet: 0x00000000219ab540356cBB839Cbe05303d7705Fa).
interface IDepositContract {
    /// @notice Submitted deposit event (Eth2 deposit contract).
    event DepositEvent(
        bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index
    );

    /// @notice Submit a 32 ETH validator deposit.
    /// @param pubkey BLS12-381 public key (48 bytes).
    /// @param withdrawal_credentials Withdrawal credentials (32 bytes).
    /// @param signature BLS deposit signature (96 bytes).
    /// @param deposit_data_root SSZ deposit data root.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Current deposit tree root.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Number of deposits as little-endian 8-byte value.
    function get_deposit_count() external view returns (bytes memory);
}
