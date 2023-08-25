// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Engine} from "../Engine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEngine {
    // Events
    event VaultCreated(uint64 indexed vaultId, address collateralAddress);
    event Deposit(uint64 indexed vaultId, address indexed from, uint256 amount);
    event Withdraw(uint64 indexed vaultId, address indexed to, uint256 amount);
    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amountCollateral,
        uint256 amountToBorrow
    );
    event PositionCanceled(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amountCollateral,
        uint256 amountToBorrow
    );
    event StrengthenPosition(
        uint256 indexed positionId,
        uint256 amountCollateralToStrengthen
    );
    event PositionPartialLiquidated(
        uint256 indexed positionId,
        uint256 amountTcUSDToCover,
        uint256 amountCollateralEarned
    );
    event PositionFullyLiquidated(
        uint256 indexed positionId,
        uint256 amountTcUSDToCover,
        uint256 amountCollateralEarned
    );

    // External Functions
    function createVault(
        IERC20 collateral,
        address priceFeed
    ) external returns (address);

    function setPriceFeed(uint64 vaultId, address priceFeed) external;

    function depositCollateral(uint64 vaultId, uint256 amount) external payable;

    function withdrawCollateral(uint64 vaultId, uint256 amount) external;

    function createPosition(
        uint64 vaultId,
        uint256 amountCollateral,
        uint256 amountToBorrow
    ) external;

    function cancelPosition(uint256 positionId) external;

    function strengthenPosition(
        uint256 positionId,
        uint256 amountToStrengthen
    ) external;

    function liquidatePosition(
        uint256 positionId,
        uint256 amountTcUSDToCover
    ) external payable;

    // Getter Functions
    function getVaultAddress(uint64 vaultId) external view returns (address);

    function getCurrentVaultId() external view returns (uint64);

    function getVaultBalance(uint64 vaultId) external view returns (uint256);

    function getAmountCanBorrow(uint64 vaultId) external view returns (uint256);

    function getCalculateAmountToBorrow(
        uint64 vaultId,
        uint256 collateralAmount
    ) external view returns (uint256);

    function getCollateralDeposited(
        uint64 vaultId
    ) external view returns (uint256);

    function getUSDValueOfCollateral(
        address collateral,
        uint256 amount
    ) external view returns (uint256);

    function getCurrentPositionId() external view returns (uint256);

    function getUniquePosition(
        uint256 positionId
    )
        external
        view
        returns (
            uint64 vaultId,
            address owner,
            uint256 amountCollateral,
            uint256 amountToBorrow,
            uint256 healthFactor
        );

    function getPositionHealthFactor(
        uint256 positionId
    ) external view returns (uint256);

    function countPosition(address owner) external view returns (uint256);

    function getAllPositionExists(
        address owner
    ) external view returns (uint256[] memory);

    function getAllLowHealthFactorPositions()
        external
        view
        returns (uint256[] memory);

    function getUniquePositionExists(
        uint256 positionId
    ) external view returns (bool);

    function getCalculateHealthFactor(
        uint256 amountBorrow,
        uint256 collateralValueInUSD
    ) external pure returns (uint256);

    function getCollateralAmountFromValue(
        address collateral,
        uint256 usdAmountInWei
    ) external view returns (uint256);
}
