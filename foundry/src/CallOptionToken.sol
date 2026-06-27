// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CallOptionToken
/// @notice ETH 看涨期权 ERC20：1 token (1e18) = 以行权价购买 1 ETH 的权利
contract CallOptionToken is ERC20, Ownable {
    /// @dev 行权价：每 1 ETH 需支付的 USDT 数量（18 位精度）
    uint256 public immutable strikePrice;
    /// @dev 到期日时间戳（UTC 日边界用于判断行权窗口）
    uint256 public immutable expiry;
    IERC20 public immutable paymentToken;

    event OptionsIssued(address indexed issuer, uint256 ethAmount, uint256 optionAmount);
    event OptionsExercised(address indexed user, uint256 optionAmount, uint256 usdtPaid, uint256 ethReceived);
    event ExpiredRedeemed(address indexed issuer, uint256 ethAmount);
    event ExpiredOptionsBurned(uint256 burnedAmount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 strikePrice_,
        uint256 expiry_,
        IERC20 paymentToken_,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        require(strikePrice_ > 0, "CallOptionToken: zero strike");
        require(expiry_ > block.timestamp, "CallOptionToken: expiry in past");
        strikePrice = strikePrice_;
        expiry = expiry_;
        paymentToken = paymentToken_;
    }

    /// @notice 是否为到期日当天（允许行权）
    function isExerciseDay() public view returns (bool) {
        return block.timestamp / 1 days == expiry / 1 days;
    }

    /// @notice 是否已过到期日（允许项目方赎回标的）
    function isExpired() public view returns (bool) {
        return block.timestamp / 1 days > expiry / 1 days;
    }

    /// @notice 项目方发行：转入 ETH 作为抵押，按 1:1 铸造期权 Token
    function issue() external payable onlyOwner {
        require(msg.value > 0, "CallOptionToken: zero eth");
        _mint(msg.sender, msg.value);
        emit OptionsIssued(msg.sender, msg.value, msg.value);
    }

    /// @notice 用户行权：到期日当天，支付行权价 USDT，销毁期权 Token，取回 ETH
    function exercise(uint256 optionAmount) external {
        require(isExerciseDay(), "CallOptionToken: not exercise day");
        require(optionAmount > 0, "CallOptionToken: zero amount");
        require(balanceOf(msg.sender) >= optionAmount, "CallOptionToken: insufficient options");
        require(address(this).balance >= optionAmount, "CallOptionToken: insufficient collateral");

        uint256 usdtPayment = (optionAmount * strikePrice) / 1e18;
        _burn(msg.sender, optionAmount);
        paymentToken.transferFrom(msg.sender, owner(), usdtPayment);

        (bool sent,) = msg.sender.call{value: optionAmount}("");
        require(sent, "CallOptionToken: eth transfer failed");

        emit OptionsExercised(msg.sender, optionAmount, usdtPayment, optionAmount);
    }

    /// @notice 项目方过期处理：批量销毁期权并赎回剩余 ETH 抵押
    /// @dev holders 列表由项目方离线收集，教学示例中用它来模拟“销毁所有期权”
    function redeemExpired(address[] calldata holders) external onlyOwner {
        require(isExpired(), "CallOptionToken: not expired");

        uint256 burned;
        uint256 length = holders.length;
        for (uint256 i = 0; i < length; i++) {
            address holder = holders[i];
            uint256 balance = balanceOf(holder);
            if (balance > 0) {
                _burn(holder, balance);
                burned += balance;
            }
        }
        require(totalSupply() == 0, "CallOptionToken: unburned options");
        emit ExpiredOptionsBurned(burned);

        uint256 amount = address(this).balance;
        require(amount > 0, "CallOptionToken: no collateral");

        (bool sent,) = owner().call{value: amount}("");
        require(sent, "CallOptionToken: eth transfer failed");

        emit ExpiredRedeemed(owner(), amount);
    }

    receive() external payable {}
}
