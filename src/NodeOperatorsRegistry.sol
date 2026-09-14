// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {INodeOperatorsRegistry} from "./interfaces/INodeOperatorsRegistry.sol";
import {LiquidStakingErrors} from "./errors/LiquidStakingErrors.sol";

/// @title NodeOperatorsRegistry
/// @notice Stores validator signing keys and assigns them to the staking pool for deposits.
contract NodeOperatorsRegistry is INodeOperatorsRegistry, Ownable2Step {
    uint256 private constant PUBKEY_LENGTH = 48;
    uint256 private constant SIGNATURE_LENGTH = 96;

    struct Operator {
        string name;
        address rewardAddress;
        bool active;
        uint64 totalSigningKeys;
        uint64 usedSigningKeys;
    }

    /// @notice Pool authorized to assign keys.
    address public pool;

    /// @dev Operators by id.
    mapping(uint256 => Operator) private _operators;

    /// @dev Packed pubkey per operator key index.
    mapping(uint256 => mapping(uint256 => bytes)) private _pubkeys;

    /// @dev Packed signature per operator key index.
    mapping(uint256 => mapping(uint256 => bytes)) private _signatures;

    /// @inheritdoc INodeOperatorsRegistry
    uint256 public override getNodeOperatorsCount;

    /// @param owner_ Admin.
    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
    }

    /// @notice Sets the staking pool allowed to assign keys. Only owner.
    function setPool(address pool_) external onlyOwner {
        if (pool_ == address(0)) revert LiquidStakingErrors.ZeroAddress();
        pool = pool_;
    }

    /// @inheritdoc INodeOperatorsRegistry
    function addNodeOperator(string calldata name, address rewardAddress)
        external
        onlyOwner
        returns (uint256 operatorId)
    {
        if (rewardAddress == address(0)) revert LiquidStakingErrors.ZeroAddress();
        operatorId = getNodeOperatorsCount;
        _operators[operatorId] =
            Operator({name: name, rewardAddress: rewardAddress, active: true, totalSigningKeys: 0, usedSigningKeys: 0});
        unchecked {
            getNodeOperatorsCount = operatorId + 1;
        }
        emit NodeOperatorAdded(operatorId, name, rewardAddress);
    }

    /// @inheritdoc INodeOperatorsRegistry
    function addSigningKeys(uint256 operatorId, uint256 count, bytes calldata pubkeys, bytes calldata signatures)
        external
        onlyOwner
    {
        if (operatorId >= getNodeOperatorsCount) revert LiquidStakingErrors.InvalidReport();
        if (count == 0) revert LiquidStakingErrors.InvalidReport();
        if (pubkeys.length != count * PUBKEY_LENGTH) revert LiquidStakingErrors.InvalidReport();
        if (signatures.length != count * SIGNATURE_LENGTH) revert LiquidStakingErrors.InvalidReport();

        Operator storage op = _operators[operatorId];
        uint256 start = op.totalSigningKeys;
        for (uint256 i = 0; i < count;) {
            uint256 keyIndex = start + i;
            _pubkeys[operatorId][keyIndex] = pubkeys[i * PUBKEY_LENGTH:(i + 1) * PUBKEY_LENGTH];
            _signatures[operatorId][keyIndex] = signatures[i * SIGNATURE_LENGTH:(i + 1) * SIGNATURE_LENGTH];
            unchecked {
                ++i;
            }
        }
        op.totalSigningKeys = uint64(start + count);
        emit SigningKeysAdded(operatorId, count);
    }

    /// @inheritdoc INodeOperatorsRegistry
    function assignNextSigningKeys(uint256 depositsCount)
        external
        returns (bytes memory pubkeys, bytes memory signatures)
    {
        if (msg.sender != pool) revert LiquidStakingErrors.OnlyPool();
        if (depositsCount == 0) revert LiquidStakingErrors.InvalidReport();
        if (getUnusedSigningKeyCount() < depositsCount) revert LiquidStakingErrors.NoSigningKeys();

        pubkeys = new bytes(depositsCount * PUBKEY_LENGTH);
        signatures = new bytes(depositsCount * SIGNATURE_LENGTH);

        uint256 assigned;
        uint256 ops = getNodeOperatorsCount;
        for (uint256 opId = 0; opId < ops && assigned < depositsCount;) {
            Operator storage op = _operators[opId];
            if (op.active) {
                while (op.usedSigningKeys < op.totalSigningKeys && assigned < depositsCount) {
                    uint256 keyIndex = op.usedSigningKeys;
                    bytes memory pk = _pubkeys[opId][keyIndex];
                    bytes memory sig = _signatures[opId][keyIndex];
                    for (uint256 j = 0; j < PUBKEY_LENGTH;) {
                        pubkeys[assigned * PUBKEY_LENGTH + j] = pk[j];
                        unchecked {
                            ++j;
                        }
                    }
                    for (uint256 j = 0; j < SIGNATURE_LENGTH;) {
                        signatures[assigned * SIGNATURE_LENGTH + j] = sig[j];
                        unchecked {
                            ++j;
                        }
                    }
                    unchecked {
                        op.usedSigningKeys += 1;
                        ++assigned;
                    }
                }
            }
            unchecked {
                ++opId;
            }
        }

        if (assigned != depositsCount) revert LiquidStakingErrors.NoSigningKeys();
        emit SigningKeysAssigned(depositsCount);
    }

    /// @inheritdoc INodeOperatorsRegistry
    function getUnusedSigningKeyCount() public view returns (uint256 unused) {
        uint256 ops = getNodeOperatorsCount;
        for (uint256 i = 0; i < ops;) {
            Operator storage op = _operators[i];
            if (op.active && op.totalSigningKeys > op.usedSigningKeys) {
                unchecked {
                    unused += op.totalSigningKeys - op.usedSigningKeys;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns operator metadata.
    function getNodeOperator(uint256 operatorId)
        external
        view
        returns (string memory name, address rewardAddress, bool active, uint64 totalSigningKeys, uint64 usedSigningKeys)
    {
        Operator storage op = _operators[operatorId];
        return (op.name, op.rewardAddress, op.active, op.totalSigningKeys, op.usedSigningKeys);
    }
}
