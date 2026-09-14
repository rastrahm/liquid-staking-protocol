// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title INodeOperatorsRegistry
/// @notice Registry of node operators and unused validator signing keys.
interface INodeOperatorsRegistry {
    /// @notice Emitted when a node operator is added.
    event NodeOperatorAdded(uint256 indexed operatorId, string name, address rewardAddress);

    /// @notice Emitted when signing keys are added.
    event SigningKeysAdded(uint256 indexed operatorId, uint256 count);

    /// @notice Emitted when keys are assigned for deposits.
    event SigningKeysAssigned(uint256 count);

    /// @notice Adds a node operator. Returns its id.
    function addNodeOperator(string calldata name, address rewardAddress) external returns (uint256 operatorId);

    /// @notice Adds `count` signing keys for an operator.
    /// @param operatorId Operator id.
    /// @param count Number of keys.
    /// @param pubkeys Concatenated 48-byte pubkeys.
    /// @param signatures Concatenated 96-byte signatures.
    function addSigningKeys(uint256 operatorId, uint256 count, bytes calldata pubkeys, bytes calldata signatures)
        external;

    /// @notice Assigns the next `depositsCount` unused keys (pool only).
    /// @return pubkeys Concatenated pubkeys.
    /// @return signatures Concatenated signatures.
    function assignNextSigningKeys(uint256 depositsCount)
        external
        returns (bytes memory pubkeys, bytes memory signatures);

    /// @notice Keys available across all active operators.
    function getUnusedSigningKeyCount() external view returns (uint256);

    /// @notice Number of registered operators.
    function getNodeOperatorsCount() external view returns (uint256);
}
