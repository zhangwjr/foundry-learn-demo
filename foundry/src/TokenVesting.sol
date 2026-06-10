// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TokenVesting
/// @notice ERC20 vesting with a cliff followed by linear release.
/// @dev Schedule: 12-month cliff, then linear unlock over 24 months (1/24 per month from month 13).
contract TokenVesting {
    using SafeERC20 for IERC20;

    event ERC20Released(address indexed token, uint256 amount);

    /// @dev 12 months cliff, 24 months linear vesting after cliff.
    uint64 public constant CLIFF_DURATION = 12 * 30 days;
    uint64 public constant VESTING_DURATION = 24 * 30 days;
    uint256 public constant VESTING_AMOUNT = 1_000_000 * 10 ** 18;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable start;
    uint256 public immutable totalAmount;

    uint256 private _released;

    /// @param beneficiary_ Address that receives vested tokens.
    /// @param token_ ERC20 token to vest.
    /// @param totalAmount_ Total tokens locked for vesting (default 1M when deploying via script).
    constructor(address beneficiary_, IERC20 token_, uint256 totalAmount_) {
        require(beneficiary_ != address(0), "TokenVesting: beneficiary is zero");
        require(totalAmount_ > 0, "TokenVesting: amount is zero");

        beneficiary = beneficiary_;
        token = token_;
        totalAmount = totalAmount_;
        start = uint64(block.timestamp);
    }

    /// @notice Cliff end timestamp (vesting starts after this).
    function cliff() public view returns (uint256) {
        return start + CLIFF_DURATION;
    }

    /// @notice Vesting end timestamp (100% unlocked).
    function end() public view returns (uint256) {
        return start + CLIFF_DURATION + VESTING_DURATION;
    }

    /// @notice Amount of tokens already released to beneficiary.
    function released() public view returns (uint256) {
        return _released;
    }

    /// @notice Vested amount at a given timestamp.
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        return _vestingSchedule(totalAmount, timestamp);
    }

    /// @notice Tokens currently available to release.
    function releasable() public view returns (uint256) {
        uint256 vested = vestedAmount(uint64(block.timestamp));
        return vested > _released ? vested - _released : 0;
    }

    /// @notice Release all currently vested tokens to the beneficiary.
    function release() external {
        uint256 amount = releasable();
        require(amount > 0, "TokenVesting: no tokens to release");

        _released += amount;
        emit ERC20Released(address(token), amount);
        token.safeTransfer(beneficiary, amount);
    }

    /// @dev Linear vesting from cliff end to `end()`. Inspired by OpenZeppelin VestingWalletCliff.
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view returns (uint256) {
        uint64 cliffEnd = uint64(start + CLIFF_DURATION);
        if (timestamp < cliffEnd) {
            return 0;
        }

        uint64 vestingEnd = uint64(start + CLIFF_DURATION + VESTING_DURATION);
        if (timestamp >= vestingEnd) {
            return totalAllocation;
        }

        return (totalAllocation * (timestamp - cliffEnd)) / VESTING_DURATION;
    }
}
