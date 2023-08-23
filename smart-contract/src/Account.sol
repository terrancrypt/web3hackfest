// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Account {
    error Account__MustBeOwner(address owner);

    uint64 private immutable i_accountId;
    address private immutable i_owner;

    constructor(uint64 accountId, address owner) {
        i_accountId = accountId;
        i_owner = owner;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert Account__MustBeOwner(i_owner);
        }
        _;
    }
}
