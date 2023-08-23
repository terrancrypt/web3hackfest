// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockWETH is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for ERC20;

    uint256 public constant MAX_FAUCET_AMOUNT = 10 * 10 ** 18; // 10 WETH in Wei

    constructor() ERC20("Wrapped ETH", "WETH") {}

    function mint(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function faucet() external {
        _mint(msg.sender, MAX_FAUCET_AMOUNT);
    }
}
