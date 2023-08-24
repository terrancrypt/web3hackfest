// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {TcUSD} from "./TcUSD.sol";

contract Engine is Ownable {
    // ===== Error
    error Engine__InvalidVault();
    error Engine__InvalidCollateral();
    error Engine__CollateralExisted();
    error Engine__InvalidPriceFeed();
    error Engine__InsufficientBalance();
    error Engine__BreaksHealthFactor();
    error Engine__ExceedsAllowedAmount();
    error Engine__PositionNotExists(uint256 positionId);
    error Engine__OnlyPositionOwner(address positionOwner);

    using OracleLibrary for AggregatorV3Interface;
    using SafeERC20 for IERC20;
    using Arrays for uint256[];

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
    mapping(address owner => uint256[] positionId) private s_onwerPosition;
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
        if (s_collateralExists[collateral] == true) {
            revert Engine__CollateralExisted();
        }
        s_vault[s_currentVaultId].collateral = collateral;
        s_priceFeed[address(collateral)] = priceFeed;
        s_currentVaultId++;

        emit VaultCreated(s_currentVaultId, address(collateral));

        return address(collateral);
    }

    function depositCollateral(
        uint64 vaultId,
        uint256 amount
    ) external payable {
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

    function withdrawCollateral(uint64 vaultId, uint256 amount) external {
        IERC20 vaultAddress = s_vault[vaultId].collateral;
        Vault storage vault = s_vault[vaultId];
        if (address(vaultAddress) == address(0)) {
            revert Engine__InvalidVault();
        }
        if (vault.userBalance[msg.sender] < amount) {
            revert Engine__InsufficientBalance();
        }
        vault.totalBalance -= amount;
        vault.userBalance[msg.sender] -= amount;
        vaultAddress.safeTransfer(msg.sender, amount);
        emit Withdraw(vaultId, msg.sender, amount);
    }

    function createPosition(
        uint64 vaultId,
        uint256 amountCollateral,
        uint256 amountToBorrow
    ) external {
        Vault storage vault = s_vault[vaultId];
        if (address(vault.collateral) == address(0)) {
            revert Engine__InvalidVault();
        }
        if (amountCollateral > vault.userBalance[msg.sender]) {
            revert Engine__InsufficientBalance();
        }
        uint256 amountTcUSDCanBorrow = _calculateAmountCanBorrow(
            address(vault.collateral),
            amountCollateral
        );
        if (amountTcUSDCanBorrow < amountToBorrow) {
            revert Engine__ExceedsAllowedAmount();
        }
        Position storage position = s_position[s_currentPositionId];

        vault.userBalance[msg.sender] -= amountCollateral;
        position.vaultId = vaultId;
        position.owner = msg.sender;
        position.amountCollateral = amountCollateral;
        position.amountToBorrow += amountToBorrow;
        s_onwerPosition[msg.sender].push(s_currentPositionId);
        s_positionExists[s_currentPositionId] = true;

        i_tcUSD.mint(msg.sender, amountToBorrow);
        emit PositionCreated(
            s_currentPositionId,
            msg.sender,
            amountCollateral,
            amountToBorrow
        );
        s_currentPositionId++;
    }

    function cancelPosition(uint256 positionId) external {
        if (s_positionExists[positionId] == false) {
            revert Engine__PositionNotExists(positionId);
        }
        _revertIfHealthFactorIsBroken(positionId);
        (
            uint64 vaultId,
            address owner,
            uint256 amountCollateral,
            uint256 amountToBorrow,

        ) = getUniquePosition(positionId);
        if (owner != msg.sender) {
            revert Engine__OnlyPositionOwner(owner);
        }
        uint256 amountTcUSDOfSender = i_tcUSD.balanceOf(msg.sender);
        if (amountToBorrow > amountTcUSDOfSender) {
            revert Engine__InsufficientBalance();
        }

        s_vault[vaultId].userBalance[msg.sender] += amountCollateral;
        s_positionExists[positionId] = false;
        i_tcUSD.transferFrom(msg.sender, address(this), amountToBorrow);
        i_tcUSD.burn(amountToBorrow);

        emit PositionCanceled(
            positionId,
            msg.sender,
            amountCollateral,
            amountToBorrow
        );
    }

    function strengthenPosition() external {}

    function _calculateAmountCanBorrow(
        address collateral,
        uint256 collateralAmount
    ) internal view returns (uint256 amountInWei) {
        uint256 usdValueOfCollateral = _getUSDValue(
            collateral,
            collateralAmount
        );
        uint256 amountTcUSDUserCanMint = (usdValueOfCollateral * 45) / 100;
        return amountInWei = amountTcUSDUserCanMint;
    }

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

    function getAmountCanBorrow(uint64 vaultId) public view returns (uint256) {
        address collateral = getVaultAddress(vaultId);
        uint256 amountCollateralOfUser = getCollateralDeposited(vaultId);
        uint256 amountCanBorrowInWei = _calculateAmountCanBorrow(
            collateral,
            amountCollateralOfUser
        );
        return amountCanBorrowInWei;
    }

    function getCalculateAmountToBorrow(
        uint64 vaultId,
        uint256 collateralAmount
    ) public view returns (uint256) {
        address collateral = getVaultAddress(vaultId);
        uint256 amountCanBorrowInWei = _calculateAmountCanBorrow(
            collateral,
            collateralAmount
        );
        return amountCanBorrowInWei;
    }

    function getCollateralDeposited(
        uint64 vaultId
    ) public view returns (uint256) {
        return s_vault[vaultId].userBalance[msg.sender];
    }

    function getUSDValueOfCollateral(
        address collateral,
        uint256 amount
    ) public view returns (uint256) {
        return _getUSDValue(collateral, amount);
    }

    function getCurrentPositionId() public view returns (uint256) {
        return s_currentPositionId;
    }

    function getUniquePosition(
        uint256 positionId
    )
        public
        view
        returns (
            uint64 vaultId,
            address owner,
            uint256 amountCollateral,
            uint256 amountToBorrow,
            uint256 healthFactor
        )
    {
        Position memory position = s_position[positionId];
        vaultId = position.vaultId;
        owner = position.owner;
        amountCollateral = position.amountCollateral;
        amountToBorrow = position.amountToBorrow;
        healthFactor = _healthFactor(positionId);
    }

    function getPositionHealthFactor(
        uint256 positionId
    ) public view returns (uint256) {
        return _healthFactor(positionId);
    }

    function countPosition(address owner) public view returns (uint256) {
        return s_onwerPosition[owner].length;
    }

    function getAllPositionExists(
        address owner
    ) public view returns (uint256[] memory) {
        uint256 count = countPosition(owner);
        uint256[] memory positionExists = new uint256[](count);
        uint256 positionExistsCount = 0;

        for (uint256 i = 0; i < count; i++) {
            uint256 positionId = s_onwerPosition[owner][i];
            if (s_positionExists[positionId] == true) {
                positionExists[positionExistsCount] = positionId;
                positionExistsCount++;
            }
        }

        uint256[] memory result = new uint256[](positionExistsCount);
        for (uint256 i = 0; i < positionExistsCount; i++) {
            result[i] = positionExists[i];
        }

        return result;
    }

    function getAllLowHealthFactorPositions()
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory lowHealthFactorPositions;
        uint256 lowHealthFactorCount = 0;

        for (uint256 i = 0; i < s_currentPositionId; i++) {
            uint256 positionId = i;
            if (s_positionExists[positionId]) {
                uint256 positionHealthFactor = _healthFactor(positionId);

                if (positionHealthFactor <= MIN_HEALTH_FACTOR) {
                    lowHealthFactorPositions[lowHealthFactorCount] = positionId;
                    lowHealthFactorCount++;
                }
            }
        }

        uint256[] memory result = new uint256[](lowHealthFactorCount);
        for (uint256 i = 0; i < lowHealthFactorCount; i++) {
            result[i] = lowHealthFactorPositions[i];
        }

        return result;
    }
}
