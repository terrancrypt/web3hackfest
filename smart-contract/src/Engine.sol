// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {TcUSD} from "./TcUSD.sol";

/**
 * @title Engine for TCProtocol
 * @author Terrancrypt
 * @notice Contract chính của toàn bộ dự án tham dự VBI's Web3Hackfest
 * Engine contract bao gồm nạp, rút tài sản thế chấp, dùng tài sản thế chấp để mở vị thế vay, củng cố và đóng vị thế
 * Mục tiêu của giao thức là tạo ra một stablecoin thuật toán 1 tcUSD ~ 1 USD pegged
 */

contract Engine is ReentrancyGuard, AccessControl {
    // ===== Error
    error Engine__InvalidVault();
    error Engine__InvalidCollateral();
    error Engine__CollateralExisted();
    error Engine__InvalidPriceFeed();
    error Engine__InsufficientBalance();
    error Engine__BreaksHealthFactor();
    error Engine__ExceedsAllowedAmount();
    error Engine__PositionNotExists();
    error Engine__OnlyPositionOwner();
    error Engine__HealthFactorOk();

    // ===== Types
    using OracleLibrary for AggregatorV3Interface;
    using SafeERC20 for IERC20;
    using SafeERC20 for TcUSD;
    using Arrays for uint256[];

    // ===== State Variables
    TcUSD private immutable i_tcUSD;

    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_BONUS = 10;
    bytes32 private constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

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

    // ===== Constructor
    constructor(address _tcUSD) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        i_tcUSD = TcUSD(_tcUSD);
    }

    // ===== Events
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
    event StrengthenPositon(
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

    // ===== Modifiers
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not allowed");
        _;
    }

    modifier onlyLiquidator() {
        require(hasRole(LIQUIDATOR_ROLE, msg.sender), "Not allowed");
        _;
    }

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

    function setPriceFeed(
        uint64 vaultId,
        address priceFeed
    ) external onlyOwner {
        address collateral = getVaultAddress(vaultId);
        if (collateral == address(0)) {
            revert Engine__InvalidVault();
        }
        if (priceFeed == address(0)) {
            revert Engine__InvalidPriceFeed();
        }
        s_priceFeed[collateral] = priceFeed;
    }

    function depositCollateral(
        uint64 vaultId,
        uint256 amount
    ) external payable nonReentrant {
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

    function withdrawCollateral(
        uint64 vaultId,
        uint256 amount
    ) external nonReentrant {
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
    ) external nonReentrant {
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
            revert Engine__PositionNotExists();
        }
        _revertIfHealthFactorIsBroken(positionId);
        (
            uint64 vaultId,
            address owner,
            uint256 amountCollateral,
            uint256 amountToBorrow,

        ) = getUniquePosition(positionId);
        if (owner != msg.sender) {
            revert Engine__OnlyPositionOwner();
        }
        uint256 amountTcUSDOfSender = i_tcUSD.balanceOf(msg.sender);
        if (amountToBorrow > amountTcUSDOfSender) {
            revert Engine__InsufficientBalance();
        }

        s_vault[vaultId].userBalance[msg.sender] += amountCollateral;
        s_positionExists[positionId] = false;

        i_tcUSD.safeTransferFrom(msg.sender, address(this), amountToBorrow);
        i_tcUSD.burn(amountToBorrow);

        emit PositionCanceled(
            positionId,
            msg.sender,
            amountCollateral,
            amountToBorrow
        );
    }

    function strengthenPosition(
        uint256 positionId,
        uint256 amountToStrengthen
    ) external {
        if (s_positionExists[positionId] == false) {
            revert Engine__PositionNotExists();
        }
        _revertIfHealthFactorIsBroken(positionId);
        (uint64 vaultId, address owner, , , ) = getUniquePosition(positionId);
        if (owner != msg.sender) {
            revert Engine__OnlyPositionOwner();
        }
        uint256 amountCollateralDeposited = getCollateralDeposited(vaultId);
        if (amountCollateralDeposited < amountToStrengthen) {
            revert Engine__InsufficientBalance();
        }
        s_vault[vaultId].userBalance[msg.sender] -= amountToStrengthen;
        s_position[positionId].amountCollateral += amountToStrengthen;

        emit StrengthenPositon(positionId, amountToStrengthen);
        _revertIfHealthFactorIsBroken(positionId);
    }

    function liquidatePosition(
        uint256 positionId,
        uint256 amountTcUSDToCover
    ) external payable /*onlyLiquidator*/ nonReentrant {
        if (s_positionExists[positionId] == false) {
            revert Engine__PositionNotExists();
        }
        (
            uint64 vaultId,
            ,
            uint256 positionCollateralAmount,
            uint256 positionAmountToBorrow,
            uint256 healthFactor
        ) = getUniquePosition(positionId);
        if (healthFactor > MIN_HEALTH_FACTOR) {
            revert Engine__HealthFactorOk();
        }
        uint256 senderTcUSDAmount = i_tcUSD.balanceOf(msg.sender);
        if (senderTcUSDAmount < amountTcUSDToCover) {
            revert Engine__InsufficientBalance();
        }
        address collateral = getVaultAddress(vaultId);
        uint256 amountCollateralToLiquidate = _getCollateralAmountFormValue(
            collateral,
            amountTcUSDToCover
        );

        if (amountCollateralToLiquidate > positionCollateralAmount) {
            revert("Protocol Breaks");
            // Chúng ta sẽ không muốn trường hợp này xảy ra, chúng ta vẫn sẽ phải handle trường hợp này trong tương lai
            // Giá của tài sản thế chấp giảm quá nhanh thì liquidators không thể thanh lý hết các vị thế break health factor, khá tương tự với trường hợp của Terran LUNA
        }

        uint256 bonusCollateral = (amountCollateralToLiquidate *
            LIQUIDATION_BONUS) / 100;

        if (amountTcUSDToCover < positionAmountToBorrow) {
            _partialLiquidation(
                positionId,
                collateral,
                amountTcUSDToCover,
                amountCollateralToLiquidate + bonusCollateral
            );
        } else {
            _fullyLiquidation(
                positionId,
                collateral,
                amountTcUSDToCover,
                amountCollateralToLiquidate + bonusCollateral
            );
        }
    }

    // ===== Internal Functions
    /**
     * @dev Internal function chỉ được gọi khi đã check params truyển vào
     */

    /**
     * @notice Partial liquidation => position still exists
     * Nhằm tránh trường hợp một vị thế vay quá lớn, không liquidators nào có đủ số dư để cover khoảng nợ của vị thế đó thì "một cây làm chẳng nên non, nhiều cây chụm lại ăn 10% bonus"
     * Đây là lý do sẽ phải có thanh lý vị thế một phần để nhiều liquidators có thể cover được khoản nợ của vị thế đó
     * Mặc dù đối với owner của dự án thì sẽ không có lợi về mặt tiền bạc, nhưng sẽ có lợi lớn hơn về việc an toàn giao thức
     * Tránh việc đáng tiếc xảy ra là một vị thế quá lớn, không thể đủ số dư tcUSD để cover
     */
    function _partialLiquidation(
        uint256 positionId,
        address collateral,
        uint256 amountTcUSDToCover,
        uint256 collateralBonus
    ) internal {
        Position storage position = s_position[positionId];
        position.amountCollateral -= collateralBonus;
        position.amountToBorrow -= amountTcUSDToCover;

        i_tcUSD.safeTransferFrom(msg.sender, address(this), amountTcUSDToCover);
        i_tcUSD.burn(amountTcUSDToCover);
        IERC20(collateral).safeTransfer(msg.sender, collateralBonus);

        emit PositionPartialLiquidated(
            positionId,
            amountTcUSDToCover,
            collateralBonus
        );
    }

    /**
     * @notice Full liquidation => position will be closed
     */
    function _fullyLiquidation(
        uint256 positionId,
        address collateral,
        uint256 amountTcUSDToCover,
        uint256 collateralBonus
    ) internal {
        Position storage position = s_position[positionId];
        position.amountCollateral -= collateralBonus;
        position.amountToBorrow -= amountTcUSDToCover;
        s_positionExists[positionId] = false;

        i_tcUSD.safeTransferFrom(msg.sender, address(this), amountTcUSDToCover);
        i_tcUSD.burn(amountTcUSDToCover);
        IERC20(collateral).safeTransfer(msg.sender, collateralBonus);

        // (, , uint256 restCollateralAmount, , ) = getUniquePosition(positionId);
        // IERC20(collateral).safeTransfer(owner(), restCollateralAmount);

        // => Owner can take the rest of collateral amount ? Chủ dự án có thể lấy phần còn lại sau khi đã chia cho liquidator 10% thanh lý?
        // Hoặc chúng ta có thể chọn phương pháp floating liquidation bonus để thay thế nhằm thu hút liquidators cho dự án, nếu dự án mở rộng hơn
        // Càng nhiều liquidators thì dự án càng an toàn, nhưng cũng vì vậy mà sẽ bị giảm lợi nhuận của liquidators khi tham gia vào dự án

        emit PositionFullyLiquidated(
            positionId,
            amountTcUSDToCover,
            collateralBonus
        );
    }

    function _calculateAmountCanBorrow(
        address collateral,
        uint256 collateralAmount
    ) internal view returns (uint256 amountInWei) {
        uint256 usdValueOfCollateral = _getUSDValue(
            collateral,
            collateralAmount
        );
        uint256 amountTcUSDUserCanMint = (usdValueOfCollateral * 45) / 100;
        // Chúng ta không muốn user vừa vay xong giá tài sản thế chấp bị giảm nên chỉ cho user vay 45% khả năng tổng tài sản thế chấp có thể vay
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
        address collateral = getVaultAddress(position.vaultId);
        uint256 usdValueOfCollateral = _getUSDValue(
            collateral,
            position.amountCollateral
        );
        return
            _calculateHealthFactor(
                position.amountToBorrow,
                usdValueOfCollateral
            );
    }

    /**
     * @dev Tham khảo cách tính: https://docs.aave.com/risk/asset-risk/risk-parameters
     */
    function _calculateHealthFactor(
        uint256 amountBorrowInWei,
        uint256 collateralValueInUSD
    ) internal pure returns (uint256) {
        if (amountBorrowInWei == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD *
            LIQUIDATION_THRESHOLD) / 100;
        return (collateralAdjustedForThreshold * PRECISION) / amountBorrowInWei;
    }

    function _revertIfHealthFactorIsBroken(uint256 positionId) internal view {
        uint256 positionHealthFactor = _healthFactor(positionId);
        if (positionHealthFactor < MIN_HEALTH_FACTOR) {
            revert Engine__BreaksHealthFactor();
        }
    }

    function _getCollateralAmountFormValue(
        address collateral,
        uint256 usdAmountInWei
    ) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeed[collateral]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        return ((usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    // ===== Getter Functions
    function getVaultAddress(uint64 vaultId) public view returns (address) {
        IERC20 vault = s_vault[vaultId].collateral;
        return address(vault);
    }

    function getCurrentVaultId() external view returns (uint64) {
        return s_currentVaultId;
    }

    function getVaultBalance(uint64 vaultId) external view returns (uint256) {
        return s_vault[vaultId].totalBalance;
    }

    function getAmountCanBorrow(
        uint64 vaultId
    ) external view returns (uint256) {
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
    ) external view returns (uint256) {
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
    ) external view returns (uint256) {
        return _getUSDValue(collateral, amount);
    }

    function getCurrentPositionId() external view returns (uint256) {
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
    ) external view returns (uint256) {
        return _healthFactor(positionId);
    }

    function countPosition(address owner) public view returns (uint256) {
        return s_onwerPosition[owner].length;
    }

    function getAllPositionExists(
        address owner
    ) external view returns (uint256[] memory) {
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
        external
        view
        returns (uint256[] memory)
    /*onlyOwner onlyLiquidator*/
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

    function getUniquePositionExists(
        uint256 positionId
    ) external view returns (bool) {
        return s_positionExists[positionId];
    }

    function getCalculateHealthFactor(
        uint256 amountBorrow,
        uint256 collateralValueInUSD
    ) external pure returns (uint256) {
        return _calculateHealthFactor(amountBorrow, collateralValueInUSD);
    }

    function getCollateralAmountFromValue(
        address collateral,
        uint256 usdAmountInWei
    ) external view returns (uint256) {
        return _getCollateralAmountFormValue(collateral, usdAmountInWei);
    }
}
