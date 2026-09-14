// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {StETH} from "../src/StETH.sol";
import {NodeOperatorsRegistry} from "../src/NodeOperatorsRegistry.sol";
import {MockDepositContract} from "../src/mocks/MockDepositContract.sol";
import {LiquidStakingErrors} from "../src/errors/LiquidStakingErrors.sol";

/// @title DepositBufferedEtherTest
/// @notice Validator deposits of 32 ETH via NodeOperatorsRegistry + DepositContract.
contract DepositBufferedEtherTest is Test {
    StETH internal steth;
    NodeOperatorsRegistry internal registry;
    MockDepositContract internal depositContract;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal reward = makeAddr("reward");
    address internal keeper = makeAddr("keeper");

    bytes32 internal withdrawalCredentials;

    function setUp() public {
        vm.deal(alice, 1_000 ether);

        withdrawalCredentials = bytes32(uint256(uint160(makeAddr("wc"))) | (uint256(0x01) << 248));

        steth = new StETH(owner);
        registry = new NodeOperatorsRegistry(owner);
        depositContract = new MockDepositContract();

        vm.startPrank(owner);
        steth.setDepositContract(address(depositContract));
        steth.setOperatorsRegistry(address(registry));
        steth.setWithdrawalCredentials(withdrawalCredentials);
        registry.setPool(address(steth));
        registry.addNodeOperator("Op0", reward);
        vm.stopPrank();
    }

    function _addKeys(uint256 count) internal {
        bytes memory pubkeys = new bytes(count * 48);
        bytes memory signatures = new bytes(count * 96);
        for (uint256 i = 0; i < count * 48; ++i) {
            pubkeys[i] = bytes1(uint8(i + 1));
        }
        for (uint256 i = 0; i < count * 96; ++i) {
            signatures[i] = bytes1(uint8(i + 2));
        }
        vm.prank(owner);
        registry.addSigningKeys(0, count, pubkeys, signatures);
    }

    function test_depositBufferedEther_singleValidator() public {
        _addKeys(1);

        vm.prank(alice);
        steth.submit{value: 32 ether}();

        uint256 pooledBefore = steth.getTotalPooledEther();
        assertEq(steth.getBufferedEther(), 32 ether);

        vm.prank(keeper);
        uint256 count = steth.depositBufferedEther(1);

        assertEq(count, 1);
        assertEq(steth.depositedValidators(), 1);
        assertEq(steth.getBufferedEther(), 0);
        assertEq(steth.getClBalance(), 32 ether);
        assertEq(steth.getTotalPooledEther(), pooledBefore); // pooled unchanged
        assertEq(depositContract.depositCount(), 1);
        assertEq(depositContract.totalDeposited(), 32 ether);
        assertEq(address(depositContract).balance, 32 ether);
        assertEq(address(steth).balance, 0);
        assertEq(registry.getUnusedSigningKeyCount(), 0);
    }

    function test_depositBufferedEther_multiple_respectsMaxDeposits() public {
        _addKeys(3);

        vm.prank(alice);
        steth.submit{value: 96 ether}();

        vm.prank(keeper);
        uint256 count = steth.depositBufferedEther(2);

        assertEq(count, 2);
        assertEq(steth.depositedValidators(), 2);
        assertEq(steth.getBufferedEther(), 32 ether);
        assertEq(steth.getClBalance(), 64 ether);
        assertEq(depositContract.depositCount(), 2);
        assertEq(registry.getUnusedSigningKeyCount(), 1);
    }

    function test_depositBufferedEther_insufficientBuffer_reverts() public {
        _addKeys(1);
        vm.prank(alice);
        steth.submit{value: 31 ether}();

        vm.prank(keeper);
        vm.expectRevert(LiquidStakingErrors.InsufficientBalance.selector);
        steth.depositBufferedEther(1);
    }

    function test_depositBufferedEther_noKeys_reverts() public {
        vm.prank(alice);
        steth.submit{value: 32 ether}();

        vm.prank(keeper);
        vm.expectRevert(LiquidStakingErrors.NoSigningKeys.selector);
        steth.depositBufferedEther(1);
    }

    function test_depositBufferedEther_partialBuffer_depositsFloor() public {
        _addKeys(2);
        vm.prank(alice);
        steth.submit{value: 70 ether}(); // floor = 2 * 32

        vm.prank(keeper);
        uint256 count = steth.depositBufferedEther(10);
        assertEq(count, 2);
        assertEq(steth.getBufferedEther(), 6 ether);
    }

    function test_assignKeys_onlyPool() public {
        _addKeys(1);
        vm.expectRevert(LiquidStakingErrors.OnlyPool.selector);
        registry.assignNextSigningKeys(1);
    }

    function test_withdrawalCredentials_required() public {
        StETH bare = new StETH(owner);
        MockDepositContract dc = new MockDepositContract();
        NodeOperatorsRegistry reg = new NodeOperatorsRegistry(owner);

        vm.startPrank(owner);
        bare.setDepositContract(address(dc));
        bare.setOperatorsRegistry(address(reg));
        reg.setPool(address(bare));
        // no withdrawal credentials
        vm.stopPrank();

        vm.deal(alice, 32 ether);
        vm.prank(alice);
        bare.submit{value: 32 ether}();

        vm.expectRevert(LiquidStakingErrors.InvalidReport.selector);
        bare.depositBufferedEther(1);
    }

    function test_emitsDepositedValidators() public {
        _addKeys(1);
        vm.prank(alice);
        steth.submit{value: 32 ether}();

        vm.expectEmit(true, true, true, true);
        emit StETH.DepositedValidators(1, 1);
        vm.prank(keeper);
        steth.depositBufferedEther(1);
    }

    function testFuzz_depositBufferedEther(uint8 keyCount, uint8 maxDeposits, uint256 extraWei) public {
        uint256 keys = bound(keyCount, 1, 5);
        uint256 maxDep = bound(maxDeposits, 1, 5);
        extraWei = bound(extraWei, 0, 31 ether);

        _addKeys(keys);
        uint256 submitAmount = keys * 32 ether + extraWei;
        vm.deal(alice, submitAmount);
        vm.prank(alice);
        steth.submit{value: submitAmount}();

        uint256 expected = keys < maxDep ? keys : maxDep;
        // also limited by buffer floor
        uint256 byBuffer = submitAmount / 32 ether;
        if (expected > byBuffer) expected = byBuffer;

        uint256 pooledBefore = steth.getTotalPooledEther();
        vm.prank(keeper);
        uint256 count = steth.depositBufferedEther(maxDep);

        assertEq(count, expected);
        assertEq(steth.depositedValidators(), expected);
        assertEq(steth.getTotalPooledEther(), pooledBefore);
        assertEq(depositContract.depositCount(), expected);
        assertEq(steth.getBufferedEther(), submitAmount - expected * 32 ether);
    }
}
