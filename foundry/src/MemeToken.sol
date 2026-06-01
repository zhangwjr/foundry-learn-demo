// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @notice Cloneable ERC20 implementation deployed via minimal proxy (EIP-1167).
contract MemeToken is Initializable {
    string private _name;
    string private _symbol;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    uint256 public maxSupply;
    uint256 public perMint;
    uint256 public price;
    address public creator;
    address public factory;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error MemeTokenUnauthorized();
    error MemeTokenMaxSupplyReached();

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory symbol_,
        uint256 totalSupply_,
        uint256 perMint_,
        uint256 price_,
        address creator_,
        address factory_
    ) external initializer {
        require(bytes(symbol_).length > 0, "Invalid symbol");
        require(totalSupply_ > 0, "Invalid total supply");
        require(perMint_ > 0 && perMint_ <= totalSupply_, "Invalid perMint");
        require(price_ > 0, "Invalid price");
        require(creator_ != address(0) && factory_ != address(0), "Invalid address");

        _name = "Meme";
        _symbol = symbol_;
        maxSupply = totalSupply_;
        perMint = perMint_;
        price = price_;
        creator = creator_;
        factory = factory_;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to) external {
        if (msg.sender != factory) revert MemeTokenUnauthorized();
        if (_totalSupply + perMint > maxSupply) revert MemeTokenMaxSupplyReached();

        _mint(to, perMint);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Insufficient balance");

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");

        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
