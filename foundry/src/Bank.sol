// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    address public  admin;

    // 记录每个地址的累计存款金额
    mapping(address => uint256) public balances; 

    // 存款前 3 名用户地址（按累计存款金额从高到低排序）
    address[3] public topDepositors;

    event Deposited(address indexed user, uint256 amount, uint256 totalBalance);
    event Withdrawn(address indexed admin, uint256 amount, address indexed to);

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        require(msg.sender == admin, "Only admin can call");
    }

    constructor() {
        admin = msg.sender;
    }

    // 允许通过 Metamask 等钱包直接向合约地址转账存款
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    // 可选：显式调用存款方法
    function deposit() external payable  {
        _deposit(msg.sender, msg.value);
    }

    function balance(address addr) public view  returns (uint){
        return addr.balance;
    }

    // 仅管理员可提取合约资金
    function withdraw(uint256 amount, address payable to) external onlyAdmin {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient contract balance");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdrawn(msg.sender, amount, to);
    }

    // 查询当前前三名及对应累计存款金额
    function getTop3()
        external
        view
        returns (address[3] memory users, uint256[3] memory amounts)
    {
        users = topDepositors;
        for (uint256 i = 0; i < 3; i++) {
            amounts[i] = balances[users[i]];
        }
    }

    function _deposit(address user, uint256 amount) internal virtual  {
        require(amount > 0, "Amount must be > 0");

        balances[user] += amount;
        _updateTop3(user);

        emit Deposited(user, amount, balances[user]);
    }

    function _updateTop3(address user) internal {
        // 如果用户已在榜单，先移除，稍后按最新金额重新插入
        for (uint256 i = 0; i < 3; i++) {
            if (topDepositors[i] == user) {
                for (uint256 j = i; j < 2; j++) {
                    topDepositors[j] = topDepositors[j + 1];
                }
                topDepositors[2] = address(0);
                break;
            }
        }

        uint256 userAmount = balances[user];

        // 按金额从高到低插入
        for (uint256 i = 0; i < 3; i++) {
            address current = topDepositors[i];
            if (current == address(0) || userAmount > balances[current]) {
                for (uint256 j = 2; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = user;
                break;
            }
        }
    }
}
