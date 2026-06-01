// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;

    address public projectOwner = makeAddr("projectOwner");
    address public creator = makeAddr("creator");
    address public buyer = makeAddr("buyer");

    uint256 public constant TOTAL_SUPPLY = 1_000_000 ether;
    uint256 public constant PER_MINT = 1000 ether;
    uint256 public constant PRICE = 0.001 ether;

    function setUp() public {
        vm.prank(projectOwner);
        factory = new MemeFactory();
    }

    function test_DeployMemeCreatesMinimalProxy() public {
        vm.prank(creator);
        address tokenAddr = factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);

        assertTrue(factory.isMemeToken(tokenAddr));
        assertTrue(tokenAddr != factory.memeImplementation());
        assertGt(tokenAddr.code.length, 0);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.name(), "Meme");
        assertEq(token.symbol(), "DOGE");
        assertEq(token.maxSupply(), TOTAL_SUPPLY);
        assertEq(token.perMint(), PER_MINT);
        assertEq(token.price(), PRICE);
        assertEq(token.creator(), creator);
        assertEq(token.factory(), address(factory));
        assertEq(token.totalSupply(), 0);
    }

    function test_MintMemeMintsAndSplitsFees() public {
        vm.prank(creator);
        address tokenAddr = factory.deployMeme("PEPE", TOTAL_SUPPLY, PER_MINT, PRICE);

        uint256 cost = PRICE * PER_MINT;
        uint256 projectFee = cost / 100;
        uint256 creatorFee = cost - projectFee;

        uint256 ownerBefore = projectOwner.balance;
        uint256 creatorBefore = creator.balance;

        vm.deal(buyer, cost);
        vm.prank(buyer);
        factory.mintMeme{value: cost}(tokenAddr);

        assertEq(MemeToken(tokenAddr).balanceOf(buyer), PER_MINT);
        assertEq(MemeToken(tokenAddr).totalSupply(), PER_MINT);
        assertEq(projectOwner.balance, ownerBefore + projectFee);
        assertEq(creator.balance, creatorBefore + creatorFee);
    }

    function test_MintMemeRefundsExcessPayment() public {
        vm.prank(creator);
        address tokenAddr = factory.deployMeme("SHIB", TOTAL_SUPPLY, PER_MINT, PRICE);

        uint256 cost = PRICE * PER_MINT;
        uint256 overpay = 1 ether;

        vm.deal(buyer, cost + overpay);
        vm.prank(buyer);
        factory.mintMeme{value: cost + overpay}(tokenAddr);

        assertEq(buyer.balance, overpay);
    }

    function test_RevertWhen_MintUnknownToken() public {
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        vm.expectRevert(MemeFactory.MemeFactoryInvalidToken.selector);
        factory.mintMeme{value: 1 ether}(makeAddr("fake"));
    }

    function test_RevertWhen_InsufficientPayment() public {
        vm.prank(creator);
        address tokenAddr = factory.deployMeme("CAT", TOTAL_SUPPLY, PER_MINT, PRICE);

        uint256 cost = PRICE * PER_MINT;

        vm.deal(buyer, cost - 1);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(MemeFactory.MemeFactoryInsufficientPayment.selector, cost, cost - 1)
        );
        factory.mintMeme{value: cost - 1}(tokenAddr);
    }

    function test_RevertWhen_MaxSupplyReached() public {
        vm.prank(creator);
        address tokenAddr = factory.deployMeme("ONE", PER_MINT, PER_MINT, PRICE);

        uint256 cost = PRICE * PER_MINT;

        vm.deal(buyer, cost * 2);
        vm.startPrank(buyer);
        factory.mintMeme{value: cost}(tokenAddr);
        vm.expectRevert(MemeToken.MemeTokenMaxSupplyReached.selector);
        factory.mintMeme{value: cost}(tokenAddr);
        vm.stopPrank();
    }
}
