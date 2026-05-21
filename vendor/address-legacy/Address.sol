// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Minimal Address helper for BaseERC721 template compatibility.
 * OpenZeppelin Contracts v5 removed `isContract`, but the BaseERC721
 * assignment template still relies on it.
 */
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
