// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TcUSD} from "../../src/TcUSD.sol";
import {Engine} from "../../src/Engine.sol";
import {MockWETH} from "../mocks/MockWETH.sol";

contract EngineTest is Test {
    event AccountCreated(
        uint64 indexed accountId,
        address accountAddress,
        address owner
    );

    address public owner;
    uint256 public privateKey;
    Engine public engine;
    MockWETH public weth;
    TcUSD public tcUSD;
    address public wETHPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public user = makeAddr("user");

    function setUp() public {
        (owner, privateKey) = makeAddrAndKey("Owner");
        vm.startBroadcast(privateKey);
        tcUSD = new TcUSD();
        engine = new Engine(address(tcUSD));
        tcUSD.transferOwnership(address(engine));
        weth = new MockWETH();
        vm.stopBroadcast();
    }

    function testOnlyOwnerCanCreateVault() public {
        vm.expectRevert("Ownable: caller is not the owner");
        engine.createVault(weth, wETHPriceFeed);
    }

    function testCreatedVault() public {
        uint64 vauldIdBefore = engine.getCurrentVaultId();

        vm.startPrank(owner);
        address vaultAdd = engine.createVault(weth, wETHPriceFeed);
        vm.stopPrank();

        address expectedVaultAdd = engine.getVaultAddress(vauldIdBefore);
        uint64 vaultIdAfter = engine.getCurrentVaultId();

        assertEq(vaultAdd, expectedVaultAdd);
        assertEq(vauldIdBefore + 1, vaultIdAfter);
    }
}
