// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenBank} from "../src/TokenBank.sol";

/// @dev Mainnet USDT uses a non-standard ERC20 interface (approve has no return value).
interface IUSDT {
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenBankTest is Test {
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    TokenBank internal bank;
    IUSDT internal usdt;

    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    uint256 internal constant USDT_UNIT = 1e6;

    function setUp() public {
        vm.createSelectFork("mainnet");
        bank = new TokenBank(USDT);
        usdt = IUSDT(USDT);
        deal(USDT, user, 10_000 * USDT_UNIT);
        deal(USDT, other, 10_000 * USDT_UNIT);
    }

    function test_Deposit_UpdatesUserDepositAndBankBalance() public {
        uint256 amount = 1_000 * USDT_UNIT;

        _approveUSDT(user, amount);

        uint256 userBalanceBefore = usdt.balanceOf(user);
        uint256 bankBalanceBefore = usdt.balanceOf(address(bank));

        vm.prank(user);
        bank.deposit();

        assertEq(bank.deposits(user), amount);
        assertEq(usdt.balanceOf(user), userBalanceBefore - amount);
        assertEq(usdt.balanceOf(address(bank)), bankBalanceBefore + amount);
    }

    function test_Deposit_AccumulatesOnMultipleDeposits() public {
        uint256 first = 500 * USDT_UNIT;
        uint256 second = 300 * USDT_UNIT;

        _approveUSDT(user, first);
        vm.prank(user);
        bank.deposit();
        assertEq(bank.deposits(user), first);

        _approveUSDT(user, second);
        vm.prank(user);
        bank.deposit();

        assertEq(bank.deposits(user), first + second);
        assertEq(usdt.balanceOf(address(bank)), first + second);
    }

    function test_Withdraw_ReturnsUsdtToUser() public {
        uint256 amount = 800 * USDT_UNIT;

        _approveUSDT(user, amount);
        vm.prank(user);
        bank.deposit();

        uint256 userBalanceBefore = usdt.balanceOf(user);

        vm.prank(user);
        bank.withdraw();

        assertEq(bank.deposits(user), 0);
        assertEq(usdt.balanceOf(user), userBalanceBefore + amount);
        assertEq(usdt.balanceOf(address(bank)), 0);
    }

    function test_MultipleUsers_DepositAndWithdrawIndependently() public {
        uint256 userAmount = 600 * USDT_UNIT;
        uint256 otherAmount = 400 * USDT_UNIT;

        _approveUSDT(user, userAmount);
        vm.prank(user);
        bank.deposit();

        _approveUSDT(other, otherAmount);
        vm.prank(other);
        bank.deposit();

        assertEq(bank.deposits(user), userAmount);
        assertEq(bank.deposits(other), otherAmount);
        assertEq(usdt.balanceOf(address(bank)), userAmount + otherAmount);

        vm.prank(user);
        bank.withdraw();

        assertEq(bank.deposits(user), 0);
        assertEq(bank.deposits(other), otherAmount);
        assertEq(usdt.balanceOf(address(bank)), otherAmount);
    }

    function test_RevertWhen_DepositWithoutApproval() public {
        vm.prank(user);
        vm.expectRevert("Approve tokens first");
        bank.deposit();
    }

    function test_RevertWhen_WithdrawWithoutDeposit() public {
        vm.prank(user);
        vm.expectRevert("No deposit");
        bank.withdraw();
    }

    function _approveUSDT(address owner, uint256 amount) internal {
        vm.startPrank(owner);
        // Mainnet USDT requires allowance reset before updating a non-zero value.
        if (usdt.allowance(owner, address(bank)) > 0) {
            usdt.approve(address(bank), 0);
        }
        usdt.approve(address(bank), amount);
        vm.stopPrank();
    }
}
