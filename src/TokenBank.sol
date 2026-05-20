// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenBank {
    using SafeERC20 for IERC20;

    IERC20 public token;

    mapping(address => uint256) public deposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Invalid token address");
        token = IERC20(tokenAddress);
    }

    function deposit() external {
        uint256 amount = token.allowance(msg.sender, address(this));
        require(amount > 0, "Approve tokens first");

        token.safeTransferFrom(msg.sender, address(this), amount);

        deposits[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw() external {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No deposit");

        deposits[msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}
