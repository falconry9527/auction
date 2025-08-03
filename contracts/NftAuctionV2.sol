// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NftAuction.sol";

contract NftAuctionV2 is NftAuction {
    // 新增功能：获取合约版本
    function version() external pure returns (string memory) {
        return "V2";
    }
}