// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CallOptionToken} from "./CallOptionToken.sol";

/// @title OptionMarket
/// @notice 期权 Token / USDT 低价交易对，模拟用户购买期权
contract OptionMarket is Ownable {
    CallOptionToken public immutable optionToken;
    IERC20 public immutable usdt;

    /// @dev 每 1e18 期权 Token 的 USDT 售价（权利金，低于行权价）
    uint256 public premiumPerOption;

    event PremiumUpdated(uint256 premiumPerOption);
    event OptionsDeposited(address indexed depositor, uint256 amount);
    event OptionsPurchased(address indexed buyer, uint256 optionAmount, uint256 usdtPaid);
    event UsdtWithdrawn(address indexed to, uint256 amount);

    constructor(CallOptionToken optionToken_, IERC20 usdt_, address initialOwner) Ownable(initialOwner) {
        optionToken = optionToken_;
        usdt = usdt_;
    }

    /// @notice 项目方设置期权售价（USDT / 1e18 option）
    function setPremium(uint256 premiumPerOption_) external onlyOwner {
        require(premiumPerOption_ > 0, "OptionMarket: zero premium");
        require(premiumPerOption_ < optionToken.strikePrice(), "OptionMarket: premium too high");
        premiumPerOption = premiumPerOption_;
        emit PremiumUpdated(premiumPerOption_);
    }

    /// @notice 项目方存入期权 Token 作为卖盘流动性
    function depositOptions(uint256 amount) external onlyOwner {
        require(amount > 0, "OptionMarket: zero amount");
        optionToken.transferFrom(msg.sender, address(this), amount);
        emit OptionsDeposited(msg.sender, amount);
    }

    /// @notice 用户以较低权利金购买期权
    function buyOptions(uint256 optionAmount) external {
        require(premiumPerOption > 0, "OptionMarket: premium not set");
        require(optionAmount > 0, "OptionMarket: zero amount");
        require(optionToken.balanceOf(address(this)) >= optionAmount, "OptionMarket: insufficient options");

        uint256 usdtCost = (optionAmount * premiumPerOption) / 1e18;
        usdt.transferFrom(msg.sender, address(this), usdtCost);
        optionToken.transfer(msg.sender, optionAmount);

        emit OptionsPurchased(msg.sender, optionAmount, usdtCost);
    }

    /// @notice 项目方提取销售所得 USDT
    function withdrawUsdt(uint256 amount) external onlyOwner {
        usdt.transfer(owner(), amount);
        emit UsdtWithdrawn(owner(), amount);
    }
}
