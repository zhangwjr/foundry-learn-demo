// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenVesting} from "../src/TokenVesting.sol";

contract TokenVestingTest is Test {
    MyToken internal token;
    TokenVesting internal vesting;

    address internal owner = makeAddr("owner");
    address internal beneficiary = makeAddr("beneficiary");

    uint256 internal constant VESTING_AMOUNT = 1_000_000 * 10 ** 18;

    function setUp() public {
        vm.prank(owner);
        token = new MyToken(owner);

        vm.prank(owner);
        vesting = new TokenVesting(beneficiary, token, VESTING_AMOUNT);

        vm.prank(owner);
        token.transfer(address(vesting), VESTING_AMOUNT);
    }

    function test_ConstructorSetsSchedule() public view {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.totalAmount(), VESTING_AMOUNT);
        assertEq(vesting.start(), block.timestamp);
        assertEq(vesting.cliff(), block.timestamp + 12 * 30 days);
        assertEq(vesting.end(), block.timestamp + 12 * 30 days + 24 * 30 days);
    }

    function test_DuringCliffNothingReleasable() public {
        vm.warp(vesting.cliff() - 1);
        assertEq(vesting.releasable(), 0);
        assertEq(vesting.vestedAmount(uint64(block.timestamp)), 0);
    }

    function test_AtCliffEndStillNothingReleasable() public {
        vm.warp(vesting.cliff());
        assertEq(vesting.releasable(), 0);
    }

    function test_OneMonthAfterCliffReleasesOneTwentyFourth() public {
        vm.warp(vesting.cliff() + 30 days);
        assertEq(vesting.releasable(), VESTING_AMOUNT / 24);
    }

    function test_TwelveMonthsAfterCliffReleasesHalf() public {
        vm.warp(vesting.cliff() + 12 * 30 days);
        assertEq(vesting.releasable(), VESTING_AMOUNT / 2);
    }

    function test_AfterFullVestingAllReleasable() public {
        vm.warp(vesting.end());
        assertEq(vesting.releasable(), VESTING_AMOUNT);
    }

    function test_ReleaseTransfersToBeneficiary() public {
        vm.warp(vesting.cliff() + 30 days);

        uint256 expected = VESTING_AMOUNT / 24;
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(), expected);
        assertEq(vesting.releasable(), 0);
    }

    function test_MultipleReleases() public {
        vm.warp(vesting.cliff() + 30 days);
        vesting.release();

        vm.warp(vesting.cliff() + 60 days);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), vesting.released());
        assertEq(vesting.releasable(), 0);
    }

    function test_RevertWhen_ReleaseWithNothingAvailable() public {
        vm.expectRevert("TokenVesting: no tokens to release");
        vesting.release();
    }

    function test_RevertWhen_BeneficiaryIsZero() public {
        vm.expectRevert("TokenVesting: beneficiary is zero");
        new TokenVesting(address(0), token, VESTING_AMOUNT);
    }
}
