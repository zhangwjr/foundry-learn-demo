pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {

    uint public vK;  // 100000
    uint public vETHAmount;
    uint public vUSDCAmount;

    IERC20 public USDC;  // 自己创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC
        uint256 borrowed; // 借入的资金
        int256 position;    // 虚拟 eth 持仓
    }
    mapping(address => PositionInfo) public positions;

    constructor(uint vEth, uint vUSDC, IERC20 _usdc) {
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
        USDC = _usdc;
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        PositionInfo storage pos = positions[msg.sender];

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        uint amount = _margin * level;
        uint256 borrowAmount = amount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        if (long) {
            // 用借入的 USDC 在虚拟 AMM 中买入 ETH，持仓为正
            vUSDCAmount += borrowAmount;
            uint256 newVEth = vK / vUSDCAmount;
            uint256 ethOut = vETHAmount - newVEth;
            vETHAmount = newVEth;
            pos.position = int256(ethOut);
        } else {
            // 在虚拟 AMM 中卖出 ETH 换 USDC，持仓为负
            require(vUSDCAmount > borrowAmount, "Insufficient liquidity");
            vUSDCAmount -= borrowAmount;
            uint256 newVEth = vK / vUSDCAmount;
            uint256 ethIn = newVEth - vETHAmount;
            vETHAmount = newVEth;
            pos.position = -int256(ethIn);
        }
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        PositionInfo memory pos = positions[msg.sender];
        require(pos.position != 0, "No open position");

        int256 pnl = calculatePnL(msg.sender);
        _reverseSwap(pos.position);
        delete positions[msg.sender];

        int256 payout = int256(pos.margin) + pnl;
        if (payout > 0) {
            USDC.transfer(msg.sender, uint256(payout));
        }
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        require(msg.sender != _user, "Cannot liquidate self");

        int256 pnl = calculatePnL(_user);
        require(pnl < 0 && uint256(-pnl) > position.margin * 80 / 100, "Not liquidatable");

        _reverseSwap(position.position);
        delete positions[_user];

        // 被清算用户的保证金作为清算奖励
        USDC.transfer(msg.sender, position.margin);
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        if (pos.position == 0) {
            return 0;
        }

        uint256 absPosition =
            pos.position > 0 ? uint256(pos.position) : uint256(-pos.position);
        int256 positionValue = int256(absPosition * vUSDCAmount / vETHAmount);

        if (pos.position > 0) {
            return positionValue - int256(pos.borrowed);
        }
        return int256(pos.borrowed) - positionValue;
    }

    function _reverseSwap(int256 position) internal {
        if (position > 0) {
            vETHAmount += uint256(position);
            vUSDCAmount = vK / vETHAmount;
        } else {
            uint256 ethAmount = uint256(-position);
            require(vETHAmount > ethAmount, "Insufficient liquidity");
            vETHAmount -= ethAmount;
            vUSDCAmount = vK / vETHAmount;
        }
    }
}
