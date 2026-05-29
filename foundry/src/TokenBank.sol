// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
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
        _deposit(msg.sender, amount);
    }

    /// @notice Deposit using an EIP-2612 permit signature instead of an on-chain approve.
    /// @param owner Token holder who signed the permit.
    /// @param amount Amount to deposit.
    /// @param deadline Permit signature expiration timestamp.
    /// @param v Signature component.
    /// @param r Signature component.
    /// @param s Signature component.
    function permitDeposit(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(amount > 0, "Amount must be positive");

        try IERC20Permit(address(token)).permit(owner, address(this), amount, deadline, v, r, s) {} catch {}

        _deposit(owner, amount);
    }

    function _deposit(address user, uint256 amount) internal {
        token.safeTransferFrom(user, address(this), amount);
        deposits[user] += amount;
        emit Deposited(user, amount);
    }

    function withdraw() external {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No deposit");

        deposits[msg.sender] = 0;
        token.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}
