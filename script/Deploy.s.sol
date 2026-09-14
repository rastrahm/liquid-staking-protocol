// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {StETH} from "../src/StETH.sol";
import {WstETH} from "../src/WstETH.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {AccountingOracle} from "../src/AccountingOracle.sol";
import {WithdrawalQueue} from "../src/WithdrawalQueue.sol";
import {NodeOperatorsRegistry} from "../src/NodeOperatorsRegistry.sol";
import {MockDepositContract} from "../src/mocks/MockDepositContract.sol";

/**
 * @title Deploy
 * @notice Deploys the liquid staking stack (lab / Anvil).
 * @dev Example:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env (see `.env.example`):
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `PROTOCOL_FEE_BPS` — fee on rewards (default 1000 = 10%)
 * - `TREASURY_SHARE_BPS` — share of fee to treasury (default 5000)
 * - `ORACLE_REPORT_INTERVAL` — seconds (default 3600)
 * - `TREASURY` / `NODE_OPERATORS` / `ORACLE_MEMBER` — addresses (default deployer)
 * - `WITHDRAWAL_CREDENTIALS` — bytes32 hex (default 0x01 || zeros || deployer)
 * - `USE_MOCK_DEPOSIT` — 1 = deploy MockDepositContract (default 1)
 * - `DEPOSIT_CONTRACT` — used when USE_MOCK_DEPOSIT=0
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);

        uint16 feeBps = uint16(vm.envOr("PROTOCOL_FEE_BPS", uint256(1000)));
        uint16 treasuryShareBps = uint16(vm.envOr("TREASURY_SHARE_BPS", uint256(5000)));
        uint256 reportInterval = vm.envOr("ORACLE_REPORT_INTERVAL", uint256(3600));
        address treasury = vm.envOr("TREASURY", deployer);
        address operators = vm.envOr("NODE_OPERATORS", deployer);
        address oracleMember = vm.envOr("ORACLE_MEMBER", deployer);
        bool useMockDeposit = vm.envOr("USE_MOCK_DEPOSIT", uint256(1)) != 0;

        bytes32 withdrawalCredentials = vm.envOr(
            "WITHDRAWAL_CREDENTIALS",
            bytes32(uint256(uint160(deployer)) | (uint256(0x01) << 248))
        );

        vm.startBroadcast(pk);

        StETH steth = new StETH(deployer);
        FeeDistributor fees = new FeeDistributor(feeBps, treasury, operators, treasuryShareBps);
        NodeOperatorsRegistry registry = new NodeOperatorsRegistry(deployer);
        WithdrawalQueue queue = new WithdrawalQueue(address(steth), deployer);
        WstETH wsteth = new WstETH(address(steth));

        address depositAddr;
        if (useMockDeposit) {
            depositAddr = address(new MockDepositContract());
        } else {
            depositAddr = vm.envAddress("DEPOSIT_CONTRACT");
        }

        AccountingOracle oracle =
            new AccountingOracle(address(steth), reportInterval, oracleMember, deployer);

        steth.setFeeDistributor(address(fees));
        steth.setOracle(address(oracle));
        steth.setDepositContract(depositAddr);
        steth.setOperatorsRegistry(address(registry));
        steth.setWithdrawalCredentials(withdrawalCredentials);
        steth.setWithdrawalQueue(address(queue));

        registry.setPool(address(steth));
        queue.setFinalizer(address(oracle));

        console2.log("StETH", address(steth));
        console2.log("WstETH", address(wsteth));
        console2.log("FeeDistributor", address(fees));
        console2.log("AccountingOracle", address(oracle));
        console2.log("WithdrawalQueue", address(queue));
        console2.log("NodeOperatorsRegistry", address(registry));
        console2.log("DepositContract", depositAddr);
        console2.log("feeBps", feeBps);
        console2.log("reportInterval", reportInterval);

        vm.stopBroadcast();
    }
}
