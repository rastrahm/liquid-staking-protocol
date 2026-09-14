// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

/// @title Deploy
/// @notice Deploy stub for Fase 0. Full wiring in Fase 7.
contract Deploy is Script {
    /// @notice Placeholder entrypoint; no contracts deployed in Fase 0.
    function run() external {
        vm.startBroadcast();
        // Fase 7: deploy StETH/Pool, WstETH, Oracle, WithdrawalQueue, FeeDistributor, NodeOps.
        vm.stopBroadcast();
    }
}
