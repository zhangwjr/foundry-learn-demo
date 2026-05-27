// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public outsider = makeAddr("outsider");
    address public recipient = makeAddr("recipient");

    uint256 public constant THRESHOLD = 2;

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, THRESHOLD);
        vm.deal(address(wallet), 10 ether);
    }

    function test_Constructor_SetsOwnersAndThreshold() public view {
        assertEq(wallet.owners(0), owner1);
        assertEq(wallet.owners(1), owner2);
        assertEq(wallet.owners(2), owner3);
        assertEq(wallet.threshold(), THRESHOLD);
        assertTrue(wallet.isOwner(owner1));
        assertFalse(wallet.isOwner(outsider));
    }

    function test_Proposal_CreatesProposalAndAutoConfirmsProposer() public {
        bytes memory data = "";

        vm.prank(owner1);
        uint256 proposalId = wallet.proposal(recipient, 1 ether, data);

        assertEq(proposalId, 0);
        assertEq(wallet.proposalCount(), 1);
        assertTrue(wallet.isConfirmed(proposalId, owner1));
        assertEq(_confirmations(proposalId), 1);
    }

    function test_Confirm_AddsConfirmationFromOtherOwner() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.prank(owner2);
        wallet.confirm(proposalId);

        assertTrue(wallet.isConfirmed(proposalId, owner2));
        assertEq(_confirmations(proposalId), 2);
    }

    function test_Execute_TransfersEthWhenThresholdReached() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.prank(owner2);
        wallet.confirm(proposalId);

        uint256 before = recipient.balance;

        vm.prank(outsider);
        wallet.execute(proposalId);

        assertEq(recipient.balance, before + 1 ether);
        assertTrue(_executed(proposalId));
        assertEq(address(wallet).balance, 9 ether);
    }

    function test_Execute_CanBeCalledByAnyAddress() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 0.5 ether, "");

        vm.prank(owner3);
        wallet.confirm(proposalId);

        vm.prank(outsider);
        wallet.execute(proposalId);

        assertTrue(_executed(proposalId));
    }

    function test_Execute_CallsContractFunction() public {
        MockTarget target = new MockTarget();
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));

        uint256 proposalId = _submitProposal(owner1, address(target), 0, data);

        vm.prank(owner2);
        wallet.confirm(proposalId);

        wallet.execute(proposalId);

        assertEq(target.value(), 42);
    }

    function test_RevertWhen_NonOwnerProposes() public {
        vm.prank(outsider);
        vm.expectRevert("Not owner");
        wallet.proposal(recipient, 1 ether, "");
    }

    function test_RevertWhen_NonOwnerConfirms() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.prank(outsider);
        vm.expectRevert("Not owner");
        wallet.confirm(proposalId);
    }

    function test_RevertWhen_ConfirmTwice() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.prank(owner1);
        vm.expectRevert("Already confirmed");
        wallet.confirm(proposalId);
    }

    function test_RevertWhen_ExecuteWithoutEnoughConfirmations() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.expectRevert("Not enough confirmations");
        wallet.execute(proposalId);
    }

    function test_RevertWhen_ExecuteTwice() public {
        uint256 proposalId = _submitProposal(owner1, recipient, 1 ether, "");

        vm.prank(owner2);
        wallet.confirm(proposalId);

        wallet.execute(proposalId);

        vm.expectRevert("Already executed");
        wallet.execute(proposalId);
    }

    function _submitProposal(
        address proposer,
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (uint256 proposalId) {
        vm.prank(proposer);
        proposalId = wallet.proposal(target, value, data);
    }

    function _confirmations(uint256 proposalId) internal view returns (uint256) {
        (,,, , uint256 confirmations) = wallet.proposals(proposalId);
        return confirmations;
    }

    function _executed(uint256 proposalId) internal view returns (bool) {
        (,, , bool executed,) = wallet.proposals(proposalId);
        return executed;
    }
}

contract MockTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}
