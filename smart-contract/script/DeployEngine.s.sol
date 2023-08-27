// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";

import {TcUSD} from "../src/TcUSD.sol";
import {Engine} from "../src/Engine.sol";

contract DeployEngine is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // This is a quick solution - not secure.
        vm.startBroadcast(deployerPrivateKey);
        TcUSD tcUSD = new TcUSD();
        Engine engine = new Engine(address(tcUSD));
        tcUSD.transferOwnership(address(engine));
        vm.stopBroadcast();
    }
}
