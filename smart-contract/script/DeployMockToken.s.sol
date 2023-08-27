// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockWBTC} from "../test/mocks/MockWBTC.sol";

contract DeployMockToken is Script {
    function run() external returns (MockWBTC) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockWBTC wbtc = new MockWBTC();
        vm.stopBroadcast();
        return wbtc;
    }
}
