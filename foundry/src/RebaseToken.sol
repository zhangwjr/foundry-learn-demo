// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title RebaseToken
/// @notice 演示 rebase 型通缩 Token：内部用 shares 记账，rebase 只调整全局系数
contract RebaseToken is IERC20, IERC20Metadata {
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10 ** 18;
    
    uint256 public constant REBASE_INTERVAL = 365 days;
    uint256 public constant SCALE = 1e18;
    /// @dev 每年通缩 1%，保留 99%
    uint256 public constant REBASE_FACTOR = 99;
    uint256 public constant REBASE_DIVISOR = 100;

    string private _name;
    string private _symbol;

    /// @dev 全局 rebase 系数，初始 1.0（1e18）
    uint256 private _rebaseIndex = SCALE;
    uint256 private _totalShares;
    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public lastRebaseTime;

    event Rebase(uint256 newRebaseIndex, uint256 newTotalSupply);

    constructor(address initialHolder) {
        _name = "RebaseToken";
        _symbol = "RBT";
        lastRebaseTime = block.timestamp;
        _mintShares(initialHolder, INITIAL_SUPPLY);
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function rebaseIndex() external view returns (uint256) {
        return _rebaseIndex;
    }

    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    function sharesOf(address account) external view returns (uint256) {
        return _shares[account];
    }

    function totalSupply() public view override returns (uint256) {
        return _sharesToTokens(_totalShares);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _sharesToTokens(_shares[account]);
    }

    /// @notice 每年调用一次，在上一期发行量基础上通缩 1%
    function rebase() external {
        require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, "RebaseToken: too early");
        lastRebaseTime = block.timestamp;
        _rebaseIndex = (_rebaseIndex * REBASE_FACTOR) / REBASE_DIVISOR;
        emit Rebase(_rebaseIndex, totalSupply());
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "RebaseToken: transfer from zero");
        require(to != address(0), "RebaseToken: transfer to zero");

        uint256 shareAmount = _tokensToShares(amount);
        _moveShares(from, to, shareAmount);
        emit Transfer(from, to, amount);
    }

    function _mintShares(address to, uint256 tokenAmount) internal {
        uint256 shareAmount = _tokensToShares(tokenAmount);
        _totalShares += shareAmount;
        _shares[to] += shareAmount;
        emit Transfer(address(0), to, tokenAmount);
    }

    function _moveShares(address from, address to, uint256 shareAmount) internal {
        require(_shares[from] >= shareAmount, "RebaseToken: insufficient balance");
        unchecked {
            _shares[from] -= shareAmount;
            _shares[to] += shareAmount;
        }
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "RebaseToken: approve from zero");
        require(spender != address(0), "RebaseToken: approve to zero");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "RebaseToken: insufficient allowance");
            unchecked {
                _allowances[owner][spender] = currentAllowance - amount;
            }
        }
    }

    function _sharesToTokens(uint256 shareAmount) internal view returns (uint256) {
        return (shareAmount * _rebaseIndex) / SCALE;
    }

    function _tokensToShares(uint256 tokenAmount) internal view returns (uint256) {
        return (tokenAmount * SCALE) / _rebaseIndex;
    }
}
