// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TcUSD is ERC20Burnable, Ownable {
    error TcUSD__AmountMustBeMoreThanZero();
    error TcUSD__BurnAmountExceedsBalance();
    error TcUSD__NotZeroAddress();

    uint256 private s_totalSupply;

    constructor() ERC20("TC Dollar", "tcUSD") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(_msgSender());
        if (_amount <= 0) {
            revert TcUSD__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert TcUSD__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
        s_totalSupply -= _amount;
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert TcUSD__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert TcUSD__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        s_totalSupply += _amount;
        return true;
    }

    // ===== Getter functions
    function getTotalSupply() external view returns (uint256) {
        return s_totalSupply;
    }
}
