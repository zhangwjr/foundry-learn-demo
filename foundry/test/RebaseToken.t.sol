// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token = new RebaseToken(owner);
    }

    function test_InitialSupplyAndBalance() public view {
        assertEq(token.INITIAL_SUPPLY(), 100_000_000 ether);
        assertEq(token.totalSupply(), 100_000_000 ether);
        assertEq(token.balanceOf(owner), 100_000_000 ether);
        assertEq(token.rebaseIndex(), 1e18);
        assertEq(token.totalShares(), 100_000_000 ether);
    }

    function test_RebaseReducesBalancesByOnePercent() public {
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        assertEq(ownerBalanceBefore, 100_000_000 ether);

        vm.warp(block.timestamp + token.REBASE_INTERVAL());
        token.rebase();

        uint256 expectedSupply = (ownerBalanceBefore * 99) / 100;
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(owner), expectedSupply);
        assertEq(token.rebaseIndex(), (1e18 * 99) / 100);
        // shares 不变，只有 rebaseIndex 下降
        assertEq(token.totalShares(), 100_000_000 ether);
        assertEq(token.sharesOf(owner), 100_000_000 ether);
    }

    function test_RebaseUpdatesAllHolderBalances() public {
        uint256 aliceAmount = 10_000_000 ether;
        uint256 bobAmount = 5_000_000 ether;

        vm.startPrank(owner);
        token.transfer(alice, aliceAmount);
        token.transfer(bob, bobAmount);
        vm.stopPrank();

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        vm.warp(block.timestamp + token.REBASE_INTERVAL());
        token.rebase();

        assertEq(token.balanceOf(owner), (ownerBalanceBefore * 99) / 100);
        assertEq(token.balanceOf(alice), (aliceBalanceBefore * 99) / 100);
        assertEq(token.balanceOf(bob), (bobBalanceBefore * 99) / 100);
        assertEq(
            token.balanceOf(owner) + token.balanceOf(alice) + token.balanceOf(bob),
            token.totalSupply()
        );
    }

    function test_MultipleRebasesCompoundDeflation() public {
        vm.warp(block.timestamp + token.REBASE_INTERVAL());
        token.rebase();

        vm.warp(block.timestamp + token.REBASE_INTERVAL());
        token.rebase();

        uint256 expected = (100_000_000 ether * 99 * 99) / (100 * 100);
        assertEq(token.totalSupply(), expected);
        assertEq(token.balanceOf(owner), expected);
    }

    function test_RevertWhen_RebaseTooEarly() public {
        vm.expectRevert(bytes("RebaseToken: too early"));
        token.rebase();
    }

    function test_TransferWorksAfterRebase() public {
        uint256 transferAmount = 1_000_000 ether;

        vm.prank(owner);
        token.transfer(alice, transferAmount);

        vm.warp(block.timestamp + token.REBASE_INTERVAL());
        token.rebase();

        uint256 expectedAlice = (transferAmount * 99) / 100;
        assertEq(token.balanceOf(alice), expectedAlice);

        vm.prank(alice);
        token.transfer(bob, expectedAlice / 2);

        assertEq(token.balanceOf(bob), expectedAlice / 2);
        assertEq(token.balanceOf(alice), expectedAlice - expectedAlice / 2);
    }
}
