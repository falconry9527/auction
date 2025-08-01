// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./NftAuction.sol";


contract NftAuctionV2 is NftAuction {
    // 新功能
    function testHello() public pure returns (string memory) {
        return "Hello, World!";
    }

}
