// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TcUSD} from "../../src/TcUSD.sol";
import {Engine} from "../../src/Engine.sol";
import {MockWETH} from "../mocks/MockWETH.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

/**
 * @title Unit test for Engine
 * @author Terrancrypt
 * @dev Just fork testing with Sepolia Testnet
 * @notice Run test with command: forge test --fork-url https://eth-sepolia.g.alchemy.com/v2/cs5861l2vJk5J5gmRJZgQm9gghoQ82mQ
 * @notice Run coverage with command: forge coverage --fork-url  https://eth-sepolia.g.alchemy.com/v2/cs5861l2vJk5J5gmRJZgQm9gghoQ82mQ
 */
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
    address public liquidator = makeAddr("liquidator");
    uint256 public constant WETH_FAUCET_AMOUNT = 10 ether;
    uint64 public constant WETH_VAULT_ID = 0;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant STARTING_LIQUIDATOR_AMOUNT = 10000e18;

    function setUp() public {
        (owner, privateKey) = makeAddrAndKey("Owner");
        vm.startBroadcast(privateKey);
        tcUSD = new TcUSD();
        tcUSD.mint(liquidator, STARTING_LIQUIDATOR_AMOUNT);
        engine = new Engine(address(tcUSD));
        tcUSD.transferOwnership(address(engine));
        weth = new MockWETH();
        vm.stopBroadcast();

        vm.prank(owner);
        engine.createVault(weth, wETHPriceFeed);

        vm.prank(user);
        weth.faucet();
    }

    // ===== Modifier
    modifier userWETHApporveAndDeposited() {
        vm.startPrank(user);
        weth.approve(address(engine), WETH_FAUCET_AMOUNT);
        engine.depositCollateral(WETH_VAULT_ID, WETH_FAUCET_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier userCreatedPosition() {
        vm.startPrank(user);
        weth.approve(address(engine), WETH_FAUCET_AMOUNT);
        engine.depositCollateral(WETH_VAULT_ID, WETH_FAUCET_AMOUNT);
        uint256 amountTcUSDCanBorrow = engine.getAmountCanBorrow(WETH_VAULT_ID);
        engine.createPosition(
            WETH_VAULT_ID,
            WETH_FAUCET_AMOUNT,
            amountTcUSDCanBorrow
        );
        vm.stopPrank();
        _;
    }

    modifier priceWETHDecrease() {
        uint8 DECIMALS = 8;
        int256 ETH_USD_PRICE = 1200e8; // 1 ETH = $1200 - The price of ETH in the test fork is currently $1700 [3:32 AM, August 25th, 2023].
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        vm.prank(owner);
        engine.setPriceFeed(WETH_VAULT_ID, address(mockPriceFeed));
        _;
    }

    function testPriceWETHDecrease()
        public
        userCreatedPosition
        priceWETHDecrease
    {
        (
            uint64 vaultId,
            ,
            uint256 positionAmountCollateral,
            uint256 positionAmountToBorrow,
            uint256 positionHealthFactor
        ) = engine.getUniquePosition(0);
        address collateral = engine.getVaultAddress(vaultId);
        uint256 usdValue = engine.getUSDValueOfCollateral(
            collateral,
            positionAmountCollateral
        );
        console.log("Postion Collateral Amount: ", positionAmountCollateral);
        console.log("Positon Collateral Value: ", usdValue);
        console.log("Position tcUSD Amount: ", positionAmountToBorrow);
        console.log("Position Health Factor: ", positionHealthFactor);
        assert(positionHealthFactor < MIN_HEALTH_FACTOR);
    }

    // ===== Test createVault
    function testOnlyOwnerCanCreateVault() public {
        vm.expectRevert("Not allowed");
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

    // ===== Test depositCollateral
    function testDepositCollateral() public {
        uint256 beforeUserBalance = weth.balanceOf(user);
        uint256 befforeEngineBalance = weth.balanceOf(address(engine));
        vm.startPrank(user);
        weth.approve(address(engine), WETH_FAUCET_AMOUNT);
        engine.depositCollateral(WETH_VAULT_ID, WETH_FAUCET_AMOUNT);
        uint256 expectedUserBalance = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );
        vm.stopPrank();

        uint256 expectedVaultBalance = engine.getVaultBalance(WETH_VAULT_ID);

        uint256 afterUserBalance = weth.balanceOf(user);
        uint256 afterEngineBalance = weth.balanceOf(address(engine));

        assertEq(expectedUserBalance, WETH_FAUCET_AMOUNT);
        assertEq(expectedVaultBalance, WETH_FAUCET_AMOUNT);
        assertEq((beforeUserBalance - WETH_FAUCET_AMOUNT), afterUserBalance);
        assertEq(
            (befforeEngineBalance + WETH_FAUCET_AMOUNT),
            afterEngineBalance
        );
    }

    function testRevertIfInsufficientBalance() public {
        vm.startPrank(user);
        weth.approve(address(engine), WETH_FAUCET_AMOUNT);
        vm.expectRevert(Engine.Engine__InsufficientBalance.selector);
        engine.depositCollateral(WETH_VAULT_ID, WETH_FAUCET_AMOUNT + 1);
        vm.stopPrank();
    }

    // ===== Test withdrawCollateral
    function testCanWithdrawCollateral() public userWETHApporveAndDeposited {
        uint256 beforeVaultBalance = engine.getVaultBalance(WETH_VAULT_ID);

        vm.startPrank(user);
        uint256 beforeUserAmount = engine.getCollateralDeposited(WETH_VAULT_ID);
        engine.withdrawCollateral(WETH_VAULT_ID, beforeUserAmount);
        uint256 afterUserAmount = engine.getCollateralDeposited(WETH_VAULT_ID);
        vm.stopPrank();

        uint256 afterVaultBalance = engine.getVaultBalance(WETH_VAULT_ID);

        assertEq((beforeUserAmount - beforeUserAmount), afterUserAmount);
        assertEq((beforeVaultBalance - beforeUserAmount), afterVaultBalance);
    }

    function testRevertIfInvalidVaultId() public userCreatedPosition {
        uint256 depositedCollateral = WETH_FAUCET_AMOUNT;
        vm.startPrank(user);
        vm.expectRevert(Engine.Engine__InvalidVault.selector);
        engine.withdrawCollateral(2, depositedCollateral);
        vm.stopPrank();
    }

    function testRevertIfUserDepositedAndCreatedPosition()
        public
        userCreatedPosition
    {
        uint256 depositedCollateral = WETH_FAUCET_AMOUNT;
        vm.startPrank(user);
        vm.expectRevert(Engine.Engine__InsufficientBalance.selector);
        engine.withdrawCollateral(WETH_VAULT_ID, depositedCollateral);
        vm.stopPrank();
    }

    function testCanWithdrawTheRestOfCollateralDeposited()
        public
        userWETHApporveAndDeposited
    {
        vm.startPrank(user);
        uint256 beforeCollateralDeposited = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );
        uint256 amountCollateralToBorrow = (beforeCollateralDeposited * 50) /
            100; // 50% to mortgage
        uint256 amountTcUSDCanBorrow = engine.getCalculateAmountToBorrow(
            WETH_VAULT_ID,
            amountCollateralToBorrow
        );
        engine.createPosition(
            WETH_VAULT_ID,
            amountCollateralToBorrow,
            amountTcUSDCanBorrow
        );
        uint256 afterCollateralDeposited = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );
        engine.withdrawCollateral(WETH_VAULT_ID, afterCollateralDeposited);
        uint256 afterAllAmountOfUser = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );
        vm.stopPrank();

        uint256 afterAllVaultBalance = engine.getVaultBalance(WETH_VAULT_ID);

        assertEq(
            (beforeCollateralDeposited - amountCollateralToBorrow),
            afterCollateralDeposited
        );
        assertEq(
            (beforeCollateralDeposited -
                amountCollateralToBorrow -
                afterCollateralDeposited),
            afterAllAmountOfUser
        );
        assertEq(afterAllVaultBalance, amountCollateralToBorrow);
    }

    // ===== Test createPosition
    function testCanCreatePosition() public userWETHApporveAndDeposited {
        uint256 beforePositionId = engine.getCurrentPositionId();
        vm.startPrank(user);
        uint256 beforeUserBalanceInVault = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );
        uint256 amountTcUSDCanBorrow = engine.getAmountCanBorrow(WETH_VAULT_ID);
        engine.createPosition(
            WETH_VAULT_ID,
            WETH_FAUCET_AMOUNT,
            amountTcUSDCanBorrow
        );
        uint256 afterUserBalanceInVault = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );

        vm.stopPrank();

        uint256 expectedHealthFactor = engine.getPositionHealthFactor(
            beforePositionId
        );

        (
            uint64 positionVaultId,
            address positionOwner,
            uint256 positionAmountCollateral,
            uint256 positionAmountToBorrow,
            uint256 positionHealthFactor
        ) = engine.getUniquePosition(beforePositionId);

        uint256 afterPositionId = engine.getCurrentPositionId();
        uint256 expectedBalanceOfTcUSD = tcUSD.balanceOf(user);

        assertEq(
            (beforeUserBalanceInVault - positionAmountCollateral),
            afterUserBalanceInVault
        );
        assertEq(positionVaultId, WETH_VAULT_ID);
        assertEq(positionOwner, user);
        assertEq(positionAmountCollateral, WETH_FAUCET_AMOUNT);
        assertEq(positionAmountToBorrow, amountTcUSDCanBorrow);
        assertEq(positionHealthFactor, expectedHealthFactor);
        assertEq(expectedBalanceOfTcUSD, positionAmountToBorrow);
        assertEq(beforePositionId + 1, afterPositionId);
    }

    function testRevertIfVaultNotExist() public userWETHApporveAndDeposited {
        vm.startPrank(user);
        uint256 amountTcUSDCanBorrow = engine.getAmountCanBorrow(WETH_VAULT_ID);
        vm.expectRevert(Engine.Engine__InvalidVault.selector);
        engine.createPosition(2, WETH_FAUCET_AMOUNT, amountTcUSDCanBorrow);
        vm.stopPrank();
    }

    function testRevertIfUserBalanceNotEnough() public {
        vm.startPrank(user);
        uint256 amountTcUSDCanBorrow = engine.getAmountCanBorrow(WETH_VAULT_ID);
        vm.expectRevert(Engine.Engine__InsufficientBalance.selector);
        engine.createPosition(
            WETH_VAULT_ID,
            WETH_FAUCET_AMOUNT,
            amountTcUSDCanBorrow
        );
        vm.stopPrank();
    }

    function testRevertIfAmountTcUSDCanBorrowTooMuch()
        public
        userWETHApporveAndDeposited
    {
        vm.startPrank(user);
        uint256 amountTcUSDCanBorrow = engine.getAmountCanBorrow(WETH_VAULT_ID);
        vm.expectRevert(Engine.Engine__ExceedsAllowedAmount.selector);
        engine.createPosition(
            WETH_VAULT_ID,
            WETH_FAUCET_AMOUNT,
            amountTcUSDCanBorrow + 1
        );
        vm.stopPrank();
    }

    // ===== Test cancelPosition
    function testCanCanclePosition() public userCreatedPosition {
        (
            uint64 vaultId,
            address positionOwner,
            uint256 positionAmountCollateral,
            uint256 positionAmountToBorrow,

        ) = engine.getUniquePosition(0);

        bool beforePositionExists = engine.getUniquePositionExists(0);
        uint256 beforeTotalSupply = tcUSD.totalSupply();

        vm.startPrank(user);
        uint256 beforeCollateralDeposited = engine.getCollateralDeposited(
            vaultId
        );
        tcUSD.approve(address(engine), positionAmountToBorrow);
        engine.cancelPosition(0);
        uint256 afterCollateralDeposited = engine.getCollateralDeposited(
            vaultId
        );
        vm.stopPrank();

        bool afterPositionExists = engine.getUniquePositionExists(0);
        uint256 afterTotalSupply = tcUSD.totalSupply();

        assertEq(beforePositionExists, true);
        assertEq(afterPositionExists, false);
        assertEq(positionOwner, user);
        assertEq(
            (beforeCollateralDeposited + positionAmountCollateral),
            afterCollateralDeposited
        );
        assertEq(
            (beforeTotalSupply - positionAmountToBorrow),
            afterTotalSupply
        );
    }

    function testRevertIfHealFactorBroken()
        public
        userCreatedPosition
        priceWETHDecrease
    {
        (, , , uint256 positionAmountToBorrow, ) = engine.getUniquePosition(0);

        vm.startPrank(user);
        tcUSD.approve(address(engine), positionAmountToBorrow);
        vm.expectRevert(Engine.Engine__BreaksHealthFactor.selector);
        engine.cancelPosition(0);
        vm.stopPrank();
    }

    function testRevertIfPostionAlreadyCancel() public userCreatedPosition {
        (, , , uint256 positionAmountToBorrow, ) = engine.getUniquePosition(0);
        vm.startPrank(user);
        tcUSD.approve(address(engine), positionAmountToBorrow);
        engine.cancelPosition(0);
        vm.expectRevert(Engine.Engine__PositionNotExists.selector);
        engine.cancelPosition(0);
        vm.stopPrank();
    }

    function testRevertIfNotTheOwner() public userCreatedPosition {
        vm.expectRevert(Engine.Engine__OnlyPositionOwner.selector);
        engine.cancelPosition(0);
    }

    // Test strengthenPosition
    function testCanStrengthenPostion() public userCreatedPosition {
        (
            uint64 vaultId,
            ,
            uint256 beforePositionAmountCollateral,
            ,
            uint256 beforeHealthFactor
        ) = engine.getUniquePosition(0);

        vm.startPrank(user);
        weth.faucet();
        uint256 amountToStrengthen = (WETH_FAUCET_AMOUNT * 50) / 100;
        weth.approve(address(engine), amountToStrengthen);
        engine.depositCollateral(WETH_VAULT_ID, amountToStrengthen);
        engine.strengthenPosition(vaultId, amountToStrengthen);
        vm.stopPrank();

        (
            ,
            ,
            uint256 afterPositionAmountCollateral,
            ,
            uint256 afterHealthFactor
        ) = engine.getUniquePosition(0);

        assertEq(
            (beforePositionAmountCollateral + amountToStrengthen),
            afterPositionAmountCollateral
        );
        assert(beforeHealthFactor < afterHealthFactor);
    }

    // ===== test liquidatePosition
    function testCanFullyLiquidatePosition()
        public
        userCreatedPosition
        priceWETHDecrease
    {
        (
            uint64 vaultId,
            ,
            uint256 beforePositionAmountCollateral,
            uint256 positionAmountToBorrow,

        ) = engine.getUniquePosition(0);

        address collateral = engine.getVaultAddress(vaultId);
        uint256 collateralAmountToLiquidate = engine
            .getCollateralAmountFromValue(collateral, positionAmountToBorrow);
        uint256 collateralBonus = (collateralAmountToLiquidate * 10) / 100;

        uint256 beforeTcUSDTotalSupply = tcUSD.totalSupply();

        uint256 beforeCollateralBanlanceOfSender = weth.balanceOf(liquidator);

        vm.startPrank(liquidator);
        tcUSD.approve(address(engine), positionAmountToBorrow);
        engine.liquidatePosition(0, positionAmountToBorrow);
        vm.stopPrank();

        bool positionExists = engine.getUniquePositionExists(0);

        (
            ,
            ,
            uint256 afterPositionAmountCollateral,
            uint256 afterPositionAmountToBorrow,

        ) = engine.getUniquePosition(0);

        uint256 afterTcUSDTotalSupply = tcUSD.totalSupply();

        uint256 afterCollateralBanlanceOfSender = weth.balanceOf(liquidator);

        assertEq(
            (beforePositionAmountCollateral -
                (collateralAmountToLiquidate + collateralBonus)),
            afterPositionAmountCollateral
        );
        assertEq(afterPositionAmountToBorrow, 0);
        assertEq(positionExists, false);
        assertEq(
            (beforeTcUSDTotalSupply - positionAmountToBorrow),
            afterTcUSDTotalSupply
        );
        assertEq(
            (beforeCollateralBanlanceOfSender +
                (collateralAmountToLiquidate + collateralBonus)),
            afterCollateralBanlanceOfSender
        );
    }

    function testCanPartialLiquidatePosition()
        public
        userCreatedPosition
        priceWETHDecrease
    {
        (
            uint64 vaultId,
            ,
            uint256 beforePositionAmountCollateral,
            uint256 positionAmountToBorrow,

        ) = engine.getUniquePosition(0);

        uint256 amountTcUSDToCover = (positionAmountToBorrow * 80) / 100;

        address collateral = engine.getVaultAddress(vaultId);
        uint256 collateralAmountToLiquidate = engine
            .getCollateralAmountFromValue(collateral, amountTcUSDToCover);
        uint256 collateralBonus = (collateralAmountToLiquidate * 10) / 100;

        uint256 beforeTcUSDTotalSupply = tcUSD.totalSupply();

        uint256 beforeCollateralBanlanceOfSender = weth.balanceOf(liquidator);

        vm.startPrank(liquidator);
        tcUSD.approve(address(engine), amountTcUSDToCover);
        engine.liquidatePosition(0, amountTcUSDToCover);
        vm.stopPrank();

        bool positionExists = engine.getUniquePositionExists(0);

        (
            ,
            ,
            uint256 afterPositionAmountCollateral,
            uint256 afterPositionAmountToBorrow,

        ) = engine.getUniquePosition(0);

        uint256 afterTcUSDTotalSupply = tcUSD.totalSupply();

        uint256 afterCollateralBanlanceOfSender = weth.balanceOf(liquidator);

        assertEq(
            (beforePositionAmountCollateral -
                (collateralAmountToLiquidate + collateralBonus)),
            afterPositionAmountCollateral
        );
        assertEq(
            afterPositionAmountToBorrow,
            (positionAmountToBorrow - amountTcUSDToCover)
        );
        assertEq(positionExists, true);
        assertEq(
            (beforeTcUSDTotalSupply - amountTcUSDToCover),
            afterTcUSDTotalSupply
        );
        assertEq(
            (beforeCollateralBanlanceOfSender +
                (collateralAmountToLiquidate + collateralBonus)),
            afterCollateralBanlanceOfSender
        );
    }

    function testRevertLiquidateIfHealthFactorOk() public userCreatedPosition {
        vm.startPrank(liquidator);
        vm.expectRevert(Engine.Engine__HealthFactorOk.selector);
        engine.liquidatePosition(0, 100e18);
        vm.stopPrank();
    }

    // ===== Test Getter Functions
    function testGetVaultAddress() public {
        address vaultAddress = engine.getVaultAddress(WETH_VAULT_ID);
        assertEq(vaultAddress, address(weth));
    }

    function testGetCollateralDeposited() public userWETHApporveAndDeposited {
        vm.prank(user);
        uint256 expectedAmountCollateral = engine.getCollateralDeposited(
            WETH_VAULT_ID
        );

        assertEq(WETH_FAUCET_AMOUNT, expectedAmountCollateral);
    }

    function testGetAmountCanBorrow() public userWETHApporveAndDeposited {
        vm.prank(user);
        uint256 amountUserCanMint = engine.getAmountCanBorrow(WETH_VAULT_ID);

        console.log(amountUserCanMint);
    }

    function testGetUSDValueOfCollateral() public view {
        uint256 usdValue = engine.getUSDValueOfCollateral(
            address(weth),
            10 ether
        );
        console.log(usdValue);
    }

    function testGetAllPositionExistsOfSender() public userCreatedPosition {
        uint256[] memory result = engine.getAllPositionExists(user);
        for (uint256 i = 0; i < result.length; i++) {
            console.log(result[i]);
        }
    }

    function testGetAllLowHealthFactorPositions() public view {
        uint256[] memory result = engine.getAllLowHealthFactorPositions();

        for (uint256 i = 0; i < result.length; i++) {
            console.log(result[i]);
        }
    }

    function testGetCalculateHealthFactor() public view {
        uint256 healthFactor = engine.getCalculateHealthFactor(
            7468156647585000000000,
            5000000000000000000
        );
        console.log(healthFactor);
    }

    function testGetCollateralAmountFromValue() public priceWETHDecrease {
        uint256 amountCollateral = engine.getCollateralAmountFromValue(
            address(weth),
            7428027897360000000000
        );
        console.log(amountCollateral);
    }
}
