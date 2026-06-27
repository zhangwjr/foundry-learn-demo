// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CallOptionToken} from "../src/CallOptionToken.sol";
import {OptionMarket} from "../src/OptionMarket.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CallOptionTokenTest is Test {
    uint256 internal constant STRIKE_PRICE = 2000 ether;
    uint256 internal constant PREMIUM = 50 ether;
    uint256 internal constant ISSUE_AMOUNT = 10 ether;

    MockUSDT public usdt;
    CallOptionToken public option;
    OptionMarket public market;

    address public project = makeAddr("project");
    address public user = makeAddr("user");

    uint256 public expiry;

    function setUp() public {
        expiry = block.timestamp + 30 days;

        usdt = new MockUSDT();
        vm.prank(project);
        option = new CallOptionToken("ETH Call Option", "ECO", STRIKE_PRICE, expiry, usdt, project);

        vm.prank(project);
        market = new OptionMarket(option, usdt, project);

        usdt.mint(user, 100_000 ether);
        vm.prank(user);
        usdt.approve(address(option), type(uint256).max);
        vm.prank(user);
        usdt.approve(address(market), type(uint256).max);

        vm.deal(project, 100 ether);
        vm.deal(user, 100 ether);
    }

    function test_ConstructorSetsStrikeAndExpiry() public view {
        assertEq(option.strikePrice(), STRIKE_PRICE);
        assertEq(option.expiry(), expiry);
        assertEq(address(option.paymentToken()), address(usdt));
        assertEq(option.owner(), project);
    }

    function test_ProjectIssuesOptionsWithEth() public {
        vm.prank(project);
        option.issue{value: ISSUE_AMOUNT}();

        assertEq(option.balanceOf(project), ISSUE_AMOUNT);
        assertEq(address(option).balance, ISSUE_AMOUNT);
        assertEq(option.totalSupply(), ISSUE_AMOUNT);
    }

    function test_UserBuysOptionsFromMarket() public {
        _issueAndListOptions();

        uint256 buyAmount = 2 ether;
        uint256 expectedCost = (buyAmount * PREMIUM) / 1e18;

        uint256 userUsdtBefore = usdt.balanceOf(user);
        vm.prank(user);
        market.buyOptions(buyAmount);

        assertEq(option.balanceOf(user), buyAmount);
        assertEq(usdt.balanceOf(user), userUsdtBefore - expectedCost);
        assertEq(usdt.balanceOf(address(market)), expectedCost);
    }

    function test_UserExercisesOnExpiryDay() public {
        _issueAndListOptions();

        uint256 buyAmount = 2 ether;
        vm.prank(user);
        market.buyOptions(buyAmount);

        uint256 usdtNeeded = (buyAmount * STRIKE_PRICE) / 1e18;
        usdt.mint(user, usdtNeeded);

        vm.warp(expiry);

        uint256 userEthBefore = user.balance;
        vm.prank(user);
        option.exercise(buyAmount);

        assertEq(option.balanceOf(user), 0);
        assertEq(user.balance, userEthBefore + buyAmount);
        assertEq(usdt.balanceOf(project), usdtNeeded);
        assertEq(address(option).balance, ISSUE_AMOUNT - buyAmount);
    }

    function test_ProjectRedeemsExpiredCollateral() public {
        vm.prank(project);
        option.issue{value: ISSUE_AMOUNT}();

        vm.warp(expiry + 1 days);

        uint256 projectEthBefore = project.balance;
        vm.prank(project);
        option.redeemExpired(_holders(project));

        assertEq(project.balance, projectEthBefore + ISSUE_AMOUNT);
        assertEq(address(option).balance, 0);
        assertEq(option.totalSupply(), 0);
    }

    function test_ProjectRedeemsRemainingAfterPartialExercise() public {
        _issueAndListOptions();

        uint256 buyAmount = 3 ether;
        vm.prank(user);
        market.buyOptions(buyAmount);

        usdt.mint(user, (buyAmount * STRIKE_PRICE) / 1e18);
        vm.warp(expiry);
        vm.prank(user);
        option.exercise(buyAmount);

        vm.warp(expiry + 1 days);

        uint256 remaining = ISSUE_AMOUNT - buyAmount;
        uint256 projectEthBefore = project.balance;
        vm.prank(project);
        option.redeemExpired(_holders(project, user, address(market)));

        assertEq(project.balance, projectEthBefore + remaining);
        assertEq(option.totalSupply(), 0);
    }

    function test_RevertWhen_ExerciseBeforeExpiryDay() public {
        _issueAndListOptions();
        vm.prank(user);
        market.buyOptions(1 ether);

        vm.warp(expiry - 1 days);
        vm.prank(user);
        vm.expectRevert("CallOptionToken: not exercise day");
        option.exercise(1 ether);
    }

    function test_RevertWhen_ExerciseAfterExpiryDay() public {
        _issueAndListOptions();
        vm.prank(user);
        market.buyOptions(1 ether);

        vm.warp(expiry + 1 days);
        vm.prank(user);
        vm.expectRevert("CallOptionToken: not exercise day");
        option.exercise(1 ether);
    }

    function test_RevertWhen_RedeemBeforeExpired() public {
        vm.prank(project);
        option.issue{value: ISSUE_AMOUNT}();

        vm.warp(expiry);
        vm.prank(project);
        vm.expectRevert("CallOptionToken: not expired");
        option.redeemExpired(_holders(project));
    }

    function test_RevertWhen_NonOwnerIssues() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                user
            )
        );
        option.issue{value: 1 ether}();
    }

    function test_PremiumLowerThanStrike() public view {
        assertLt(PREMIUM, STRIKE_PRICE);
    }

    function test_RevertWhen_PremiumNotLowerThanStrike() public {
        vm.prank(project);
        vm.expectRevert("OptionMarket: premium too high");
        market.setPremium(STRIKE_PRICE);
    }

    function _issueAndListOptions() internal {
        vm.prank(project);
        option.issue{value: ISSUE_AMOUNT}();

        vm.prank(project);
        option.approve(address(market), ISSUE_AMOUNT);
        vm.prank(project);
        market.depositOptions(ISSUE_AMOUNT);

        vm.prank(project);
        market.setPremium(PREMIUM);
    }

    function _holders(address a) internal pure returns (address[] memory list) {
        list = new address[](1);
        list[0] = a;
    }

    function _holders(address a, address b) internal pure returns (address[] memory list) {
        list = new address[](2);
        list[0] = a;
        list[1] = b;
    }

    function _holders(address a, address b, address c) internal pure returns (address[] memory list) {
        list = new address[](3);
        list[0] = a;
        list[1] = b;
        list[2] = c;
    }
}
