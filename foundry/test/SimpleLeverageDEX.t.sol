// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimpleLeverageDEX} from "../src/SimpleLeverageDEX.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SimpleLeverageDEXTest is Test {
    uint256 internal constant INITIAL_V_ETH = 100 ether;
    uint256 internal constant INITIAL_V_USDC = 2000 ether;
    uint256 internal constant MARGIN = 100 ether;

    MockUSDC public usdc;
    SimpleLeverageDEX public dex;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        usdc = new MockUSDC();
        dex = new SimpleLeverageDEX(INITIAL_V_ETH, INITIAL_V_USDC, usdc);

        usdc.mint(alice, 10_000 ether);
        usdc.mint(bob, 10_000 ether);
        usdc.mint(liquidator, 10_000 ether);
        usdc.mint(address(dex), 1_000_000 ether);

        vm.prank(alice);
        usdc.approve(address(dex), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(dex), type(uint256).max);
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }

    function test_InitialVirtualPool() public view {
        assertEq(dex.vETHAmount(), INITIAL_V_ETH);
        assertEq(dex.vUSDCAmount(), INITIAL_V_USDC);
        assertEq(dex.vK(), INITIAL_V_ETH * INITIAL_V_USDC);
    }

    function test_OpenLongUpdatesPoolAndPosition() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        (uint256 margin, uint256 borrowed, int256 position) = dex.positions(alice);
        assertEq(margin, MARGIN);
        assertEq(borrowed, 400 ether);
        assertGt(position, 0);

        assertEq(dex.vUSDCAmount(), INITIAL_V_USDC + borrowed);
        assertEq(dex.vETHAmount(), dex.vK() / dex.vUSDCAmount());
        assertEq(usdc.balanceOf(address(dex)), MARGIN + 1_000_000 ether);
    }

    function test_OpenShortUpdatesPoolAndPosition() public {
        vm.prank(bob);
        dex.openPosition(MARGIN, 5, false);

        (uint256 margin, uint256 borrowed, int256 position) = dex.positions(bob);
        assertEq(margin, MARGIN);
        assertEq(borrowed, 400 ether);
        assertLt(position, 0);

        assertEq(dex.vUSDCAmount(), INITIAL_V_USDC - borrowed);
        assertEq(dex.vETHAmount(), dex.vK() / dex.vUSDCAmount());
    }

    function test_CalculatePnLPositiveForLong() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        int256 pnl = dex.calculatePnL(alice);
        assertGt(pnl, 0);
    }

    function test_CalculatePnLNegativeForShortAfterPriceRises() public {
        vm.prank(bob);
        dex.openPosition(MARGIN, 5, false);

        vm.prank(alice);
        dex.openPosition(500 ether, 2, true);

        int256 pnl = dex.calculatePnL(bob);
        assertLt(pnl, 0);
    }

    function test_CloseLongReturnsMarginPlusProfit() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        int256 pnl = dex.calculatePnL(alice);
        uint256 expectedPayout = MARGIN + uint256(pnl);
        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        dex.closePosition();

        assertEq(usdc.balanceOf(alice), balanceBefore + expectedPayout);
        (,, int256 position) = dex.positions(alice);
        assertEq(position, 0);
    }

    function test_CloseLongRestoresVirtualPool() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        vm.prank(alice);
        dex.closePosition();

        assertEq(dex.vETHAmount(), INITIAL_V_ETH);
        assertEq(dex.vUSDCAmount(), INITIAL_V_USDC);
    }

    function test_CloseLongWithLossReturnsReducedPayout() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        vm.prank(bob);
        dex.openPosition(800 ether, 2, false);

        int256 pnl = dex.calculatePnL(alice);
        assertLt(pnl, 0);

        uint256 balanceBefore = usdc.balanceOf(alice);
        int256 expectedPayout = int256(MARGIN) + pnl;

        vm.prank(alice);
        dex.closePosition();

        if (expectedPayout > 0) {
            assertEq(usdc.balanceOf(alice), balanceBefore + uint256(expectedPayout));
            assertLt(uint256(expectedPayout), MARGIN);
        } else {
            assertEq(usdc.balanceOf(alice), balanceBefore);
        }

        (,, int256 position) = dex.positions(alice);
        assertEq(position, 0);
    }

    function test_LiquidatePositionTransfersMarginToLiquidator() public {
        vm.prank(bob);
        dex.openPosition(MARGIN, 5, false);

        vm.prank(alice);
        dex.openPosition(500 ether, 2, true);

        int256 pnl = dex.calculatePnL(bob);
        assertLt(pnl, 0);
        assertGt(uint256(-pnl), MARGIN * 80 / 100);

        uint256 liquidatorBefore = usdc.balanceOf(liquidator);
        vm.prank(liquidator);
        dex.liquidatePosition(bob);

        assertEq(usdc.balanceOf(liquidator), liquidatorBefore + MARGIN);
        (,, int256 position) = dex.positions(bob);
        assertEq(position, 0);
    }

    function test_RevertWhen_OpenSecondPosition() public {
        vm.prank(alice);
        dex.openPosition(MARGIN, 5, true);

        vm.prank(alice);
        vm.expectRevert("Position already open");
        dex.openPosition(MARGIN, 3, true);
    }

    function test_RevertWhen_CloseWithoutPosition() public {
        vm.prank(alice);
        vm.expectRevert("No open position");
        dex.closePosition();
    }

    function test_RevertWhen_LiquidateSelf() public {
        vm.prank(bob);
        dex.openPosition(MARGIN, 5, false);

        vm.prank(alice);
        dex.openPosition(500 ether, 2, true);

        vm.prank(bob);
        vm.expectRevert("Cannot liquidate self");
        dex.liquidatePosition(bob);
    }

    function test_RevertWhen_NotLiquidatable() public {
        vm.prank(bob);
        dex.openPosition(MARGIN, 5, true);

        vm.prank(alice);
        dex.openPosition(MARGIN, 5, false);

        int256 pnl = dex.calculatePnL(bob);
        assertLt(pnl, 0);
        assertLe(uint256(-pnl), MARGIN * 80 / 100);

        vm.prank(liquidator);
        vm.expectRevert("Not liquidatable");
        dex.liquidatePosition(bob);
    }

    function test_RevertWhen_ShortExceedsPoolLiquidity() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient liquidity");
        dex.openPosition(1500 ether, 3, false);
    }

    function testFuzz_LongOpenBorrowAmount(uint8 level) public {
        level = uint8(bound(level, 2, 10));

        vm.prank(alice);
        dex.openPosition(MARGIN, level, true);

        (, uint256 borrowed,) = dex.positions(alice);
        assertEq(borrowed, MARGIN * (level - 1));
    }
}
