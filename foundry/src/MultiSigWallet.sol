// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSigWallet
/// @notice 简单的链上多签钱包：持有人发起提案、其他持有人链上确认、达到门槛后任何人可执行
contract MultiSigWallet {
    address[] public owners;
    uint256 public threshold;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event Deposit(address indexed sender, uint256 amount);
    event ProposalSubmitted(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        bytes data
    );
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        require(isOwner(msg.sender), "Not owner");
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(
            _threshold > 0 && _threshold <= _owners.length,
            "Invalid threshold"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner(owner), "Duplicate owner");
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function isOwner(address account) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) {
                return true;
            }
        }
        return false;
    }

    function proposalCount() external view returns (uint256) {
        return proposals.length;
    }

    /// @notice 多签持有人提交交易提案，发起人自动计入一次确认
    function proposal(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 proposalId) {
        proposalId = proposals.length;

        proposals.push(
            Proposal({
                target: target,
                value: value,
                data: data,
                executed: false,
                confirmations: 1
            })
        );

        isConfirmed[proposalId][msg.sender] = true;

        emit ProposalSubmitted(proposalId, msg.sender, target, value, data);
        emit ProposalConfirmed(proposalId, msg.sender);
    }

    /// @notice 其他多签持有人通过发送交易确认提案
    function confirm(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(!isConfirmed[proposalId][msg.sender], "Already confirmed");

        isConfirmed[proposalId][msg.sender] = true;
        p.confirmations += 1;

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    /// @notice 提案达到多签门槛后，任何人都可以执行
    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.confirmations >= threshold, "Not enough confirmations");

        p.executed = true;

        (bool success, ) = p.target.call{value: p.value}(p.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }
}
