// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {TcUSD} from "./TcUSD.sol";

contract Engine is Ownable {
    // ===== Error
    error Engine__InvalidVault();
    error Engine__InvalidCollateral();
    error Engine__InvalidPriceFeed();
    error Engine__InsufficientBalance();
    error Engine__BreaksHealthFactor();

    using OracleLibrary for AggregatorV3Interface;
    using SafeERC20 for IERC20;

    // ===== Types
    TcUSD private immutable i_tcUSD;

    struct Vault {
        IERC20 collateral;
        uint256 totalBalance;
        mapping(address user => uint256 amount) userBalance;
    }
    mapping(uint64 vaultId => Vault) private s_vault;
    uint64 private s_currentVaultId;
    mapping(IERC20 collateral => bool) private s_collateralExists;
    mapping(address collateral => address priceFeed) private s_priceFeed;

    struct Position {
        uint64 vaultId;
        address owner;
        uint256 amountCollateral;
        uint256 amountToBorrow;
    }
    mapping(uint256 positionId => Position) private s_position;
    mapping(address owner => uint256 positionId) private s_onwerPosition;
    uint256 private s_currentPositionId;
    mapping(uint256 positionId => bool) private s_positionExists;

    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;

    constructor(address _tcUSD) {
        i_tcUSD = TcUSD(_tcUSD);
    }

    event VaultCreated(uint64 indexed vaultId, address collateralAddress);
    event Deposit(uint64 indexed vaultId, address indexed from, uint256 amount);
    event PositionCreated(
        uint256 indexed positionId,
        address indexed owner,
        uint256 amountCollateral,
        uint256 amountToBorrow
    );

    //===== External Functions
    function createVault(
        IERC20 collateral,
        address priceFeed
    ) external onlyOwner returns (address) {
        if (address(collateral) == address(0)) {
            revert Engine__InvalidCollateral();
        }
        if (priceFeed == address(0)) {
            revert Engine__InvalidPriceFeed();
        }
        s_vault[s_currentVaultId].collateral = collateral;
        s_priceFeed[address(collateral)] = priceFeed;
        s_currentVaultId++;

        emit VaultCreated(s_currentVaultId, address(collateral));

        return address(collateral);
    }

    function deposit(uint64 vaultId, uint256 amount) external payable {
        IERC20 vaultAddress = s_vault[vaultId].collateral;
        Vault storage vault = s_vault[vaultId];
        if (address(vaultAddress) == address(0)) {
            revert Engine__InvalidVault();
        }
        vault.totalBalance += amount;
        vault.userBalance[msg.sender] += amount;
        vaultAddress.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(vaultId, msg.sender, amount);
    }

    function createPosition(
        uint64 vaultId,
        uint256 amountCollateral,
        uint256 amountToBorrow
    ) external {
        IERC20 vaultAddress = s_vault[vaultId].collateral;
        Vault storage vault = s_vault[vaultId];
        uint256 userBalanceInVault = vault.userBalance[msg.sender];
        if (address(vaultAddress) == address(0)) {
            revert Engine__InvalidVault();
        }
        if (amountCollateral < userBalanceInVault) {
            revert Engine__InsufficientBalance();
        }
        Position storage position = s_position[s_currentPositionId];

        userBalanceInVault -= amountCollateral;
        position.vaultId = vaultId;
        position.owner = msg.sender;
        position.amountCollateral = amountCollateral;
        position.amountToBorrow += amountToBorrow;
        s_onwerPosition[msg.sender] = s_currentPositionId;

        i_tcUSD.mint(msg.sender, amountToBorrow);
        emit PositionCreated(
            s_currentPositionId,
            msg.sender,
            amountCollateral,
            amountToBorrow
        );
        s_currentPositionId++;
    }

    // function _calculateAmountCanBorrow(
    //     address collateral,
    //     uint256 collateralAmount
    // ) internal view returns (uint256) {

    // }

    function _getUSDValue(
        address collateral,
        uint256 amount
    ) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeed[collateral]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _healthFactor(uint256 positionId) private view returns (uint256) {
        Position memory position = s_position[positionId];
        address collateralAddress = getVaultAddress(position.vaultId);
        uint256 usdValueOfCollateral = _getUSDValue(
            collateralAddress,
            position.amountCollateral
        );
        return
            _calculateHealthFactor(
                position.amountToBorrow,
                usdValueOfCollateral
            );
    }

    function _calculateHealthFactor(
        uint256 amountMinted,
        uint256 collateralValueInUSD
    ) internal pure returns (uint256) {
        if (amountMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD *
            LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * PRECISION) / amountMinted;
    }

    function _revertIfHealthFactorIsBroken(uint256 positionId) internal view {
        uint256 positionHealthFactor = _healthFactor(positionId);
        if (positionHealthFactor < MIN_HEALTH_FACTOR) {
            revert Engine__BreaksHealthFactor();
        }
    }

    // ===== Getter Functions

    function getVaultAddress(uint64 vaultId) public view returns (address) {
        IERC20 vault = s_vault[vaultId].collateral;
        return address(vault);
    }

    function getCurrentVaultId() public view returns (uint64) {
        return s_currentVaultId;
    }

    function getVaultBalance(uint64 vaultId) public view returns (uint256) {
        return s_vault[vaultId].totalBalance;
    }
}
