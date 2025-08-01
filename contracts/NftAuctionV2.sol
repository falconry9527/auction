// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NftAuction.sol";

contract NftAuctionV2 is NftAuction {
    // 新增功能：拍卖延长机制
    uint256 public constant EXTENSION_DURATION = 15 minutes;
    
    // 新增事件
    event AuctionExtended(uint256 indexed tokenId, uint256 newEndTime);
    
    // 新增功能：最后时刻出价延长拍卖时间
    function placeBid(uint256 tokenId) external payable override nonReentrant {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(msg.value > auction.highestBid, "Bid too low");
        require(msg.sender != auction.seller, "Seller cannot bid");

        // 如果出价在最后15分钟内，延长拍卖时间
        if (block.timestamp > auction.endTime - EXTENSION_DURATION) {
            auction.endTime = block.timestamp + EXTENSION_DURATION;
            emit AuctionExtended(tokenId, auction.endTime);
        }
        
        // 退还前一个最高出价者的资金
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }
    
    // 新增功能：获取合约版本
    function version() external pure returns (string memory) {
        return "V2";
    }
}