// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {StETH} from "../../src/StETH.sol";
import {WstETH} from "../../src/WstETH.sol";
import {FeeDistributor} from "../../src/FeeDistributor.sol";
import {AccountingOracle} from "../../src/AccountingOracle.sol";
import {WithdrawalQueue} from "../../src/WithdrawalQueue.sol";
import {NodeOperatorsRegistry} from "../../src/NodeOperatorsRegistry.sol";
import {MockDepositContract} from "../../src/mocks/MockDepositContract.sol";

/**
 * @title LiquidStakingGasTest
 * @notice Fase 7: baseline gas for hot paths (`forge snapshot --match-contract LiquidStakingGasTest`).
 */
contract LiquidStakingGasTest is Test {
    StETH internal steth;
    WstETH internal wsteth;
    AccountingOracle internal oracle;
    WithdrawalQueue internal queue;
    NodeOperatorsRegistry internal registry;
    MockDepositContract internal depositContract;

    address internal owner = makeAddr("owner");
    address internal reporter = makeAddr("reporter");
    address internal treasury = makeAddr("treasury");
    address internal operators = makeAddr("operators");
    address internal alice = makeAddr("alice");
    address internal reward = makeAddr("reward");

    bytes32 internal wc;

    function setUp() public {
        vm.deal(alice, 1_000 ether);
        wc = bytes32(uint256(uint160(makeAddr("wc"))) | (uint256(0x01) << 248));

        steth = new StETH(owner);
        wsteth = new WstETH(address(steth));
        FeeDistributor fees = new FeeDistributor(1000, treasury, operators, 5000);
        registry = new NodeOperatorsRegistry(owner);
        depositContract = new MockDepositContract();
        queue = new WithdrawalQueue(address(steth), owner);
        oracle = new AccountingOracle(address(steth), 1 hours, reporter, owner);

        vm.startPrank(owner);
        steth.setFeeDistributor(address(fees));
        steth.setOracle(address(oracle));
        steth.setDepositContract(address(depositContract));
        steth.setOperatorsRegistry(address(registry));
        steth.setWithdrawalCredentials(wc);
        steth.setWithdrawalQueue(address(queue));
        registry.setPool(address(steth));
        registry.addNodeOperator("Op0", reward);
        queue.setFinalizer(owner);
        vm.stopPrank();

        _addKeys(2);

        // Warm state for wrap / withdraw / deposit gas paths
        vm.prank(alice);
        steth.submit{value: 64 ether}();
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

    function testGas_submit() public {
        vm.prank(alice);
        steth.submit{value: 1 ether}();
    }

    function testGas_wrap() public {
        vm.startPrank(alice);
        steth.approve(address(wsteth), 1 ether);
        wsteth.wrap(1 ether);
        vm.stopPrank();
    }

    function testGas_unwrap() public {
        vm.startPrank(alice);
        steth.approve(address(wsteth), 1 ether);
        uint256 wst = wsteth.wrap(1 ether);
        wsteth.unwrap(wst);
        vm.stopPrank();
    }

    function testGas_depositBufferedEther_oneValidator() public {
        steth.depositBufferedEther(1);
    }

    function testGas_oracleReport_positiveRebase() public {
        vm.prank(reporter);
        oracle.submitReport(1 ether, 0);
    }

    function testGas_withdrawal_requestFinalizeClaim() public {
        vm.startPrank(alice);
        steth.approve(address(queue), 1 ether);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        uint256[] memory ids = queue.requestWithdrawals(amounts, alice);
        vm.stopPrank();

        vm.prank(owner);
        queue.finalize(ids[0]);

        vm.prank(alice);
        queue.claimWithdrawal(ids[0]);
    }
}
