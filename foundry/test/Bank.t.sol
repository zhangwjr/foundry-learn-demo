// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    address public admin;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public outsider = makeAddr("outsider");

    function setUp() public {
        bank = new Bank();
        admin = bank.admin();
    }

    // --- Case 1: deposit balance updates ---

    function test_Deposit_UpdatesBalance() public {
        assertEq(bank.balances(user1), 0);

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        bank.deposit{value: 0.5 ether}();

        assertEq(bank.balances(user1), 0.5 ether);
        assertEq(address(bank).balance, 0.5 ether);
    }

    function test_Deposit_AccumulatesBalanceOnMultipleDeposits() public {
        vm.deal(user1, 2 ether);

        vm.startPrank(user1);
        bank.deposit{value: 0.3 ether}();
        assertEq(bank.balances(user1), 0.3 ether);

        bank.deposit{value: 0.7 ether}();
        assertEq(bank.balances(user1), 1 ether);
        vm.stopPrank();

        assertEq(address(bank).balance, 1 ether);
    }

    function test_Receive_UpdatesBalance() public {
        vm.deal(user1, 1 ether);

        vm.prank(user1);
        (bool ok,) = address(bank).call{value: 0.25 ether}("");
        assertTrue(ok);

        assertEq(bank.balances(user1), 0.25 ether);
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Amount must be > 0");
        bank.deposit{value: 0}();
    }

    // --- Case 2: top 3 depositors ---

    function test_Top3_WithOneUser() public {
        _deposit(user1, 100 ether);

        _assertTop3(
            [user1, address(0), address(0)],
            _amounts(100 ether, 0, 0)
        );
    }

    function test_Top3_WithTwoUsers() public {
        _deposit(user1, 100 ether);
        _deposit(user2, 200 ether);

        _assertTop3(
            [user2, user1, address(0)],
            _amounts(200 ether, 100 ether, 0)
        );
    }

    function test_Top3_WithThreeUsers() public {
        _deposit(user1, 100 ether);
        _deposit(user2, 200 ether);
        _deposit(user3, 300 ether);

        _assertTop3(
            [user3, user2, user1],
            _amounts(300 ether, 200 ether, 100 ether)
        );
    }

    function test_Top3_WithFourUsers_KeepsHighestThree() public {
        _deposit(user1, 100 ether);
        _deposit(user2, 200 ether);
        _deposit(user3, 300 ether);
        _deposit(user4, 150 ether);

        _assertTop3(
            [user3, user2, user4],
            _amounts(300 ether, 200 ether, 150 ether)
        );
    }

    function test_Top3_SameUserMultipleDeposits_AccumulatesAndReranks() public {
        _deposit(user1, 50 ether);
        _deposit(user2, 100 ether);
        _deposit(user1, 100 ether);

        _assertTop3(
            [user1, user2, address(0)],
            _amounts(150 ether, 100 ether, 0)
        );
    }

    function test_Top3_SameUserMultipleDeposits_CanBecomeFirst() public {
        _deposit(user1, 100 ether);
        _deposit(user2, 200 ether);
        _deposit(user1, 150 ether);

        _assertTop3(
            [user1, user2, address(0)],
            _amounts(250 ether, 200 ether, 0)
        );
    }

    // --- Case 3: withdraw access control ---

    function test_Withdraw_ByAdmin() public {
        _deposit(user1, 1 ether);

        address payable recipient = payable(makeAddr("recipient"));
        uint256 before = recipient.balance;

        vm.prank(admin);
        bank.withdraw(0.4 ether, recipient);

        assertEq(recipient.balance, before + 0.4 ether);
        assertEq(address(bank).balance, 0.6 ether);
    }

    function test_RevertWhen_NonAdminWithdraws() public {
        _deposit(user1, 1 ether);

        vm.prank(outsider);
        vm.expectRevert("Only admin can call");
        bank.withdraw(0.1 ether, payable(outsider));
    }

    function test_RevertWhen_UserWithdraws() public {
        _deposit(user1, 1 ether);

        vm.prank(user1);
        vm.expectRevert("Only admin can call");
        bank.withdraw(0.1 ether, payable(user1));
    }

    // --- helpers ---

    function _deposit(address user, uint256 amount) internal {
        vm.deal(user, amount);
        vm.prank(user);
        bank.deposit{value: amount}();
    }

    function _amounts(uint256 a0, uint256 a1, uint256 a2) internal pure returns (uint256[3] memory) {
        return [a0, a1, a2];
    }

    function _assertTop3(
        address[3] memory expectedUsers,
        uint256[3] memory expectedAmounts
    ) internal view {
        (address[3] memory users, uint256[3] memory amounts) = bank.getTop3();

        for (uint256 i = 0; i < 3; i++) {
            assertEq(users[i], expectedUsers[i], "top user mismatch");
            assertEq(amounts[i], expectedAmounts[i], "top amount mismatch");
        }
    }
}
