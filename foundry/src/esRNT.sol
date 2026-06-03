// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract esRNT {
    struct LockInfo {
        address user;
        uint64 startTime;
        uint256 amount;
    }

    LockInfo[] private _locks;

    constructor() {
        for (uint256 i = 0; i < 11; i++) {
            _locks.push(
                LockInfo({
                    user: address(uint160(i + 1)),
                    startTime: uint64(block.timestamp * 2 - i),
                    amount: 1e18 * (i + 1)
                })
            );
        }
    }
}
