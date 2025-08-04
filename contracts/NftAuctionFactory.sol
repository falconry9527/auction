// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
contract NftAuctionFactory {

    // 工厂模式需要部署2个合约
    // 1.工厂合约 : 使用 createAuction 创建拍卖会
    // 2.拍卖会 : NftAuctionFactory.getAuction 找到 Auction 以后，调用Auction 内部方法

    address[] public auctions;

    mapping (uint256 tokenId => NftAuction) public auctionMap;

    event AuctionCreated(address indexed auctionAddress,uint256 tokenId);

    // Create a new auction
    function createAuction(
        uint256 duration,
        uint256 startPrice,
        address nftContractAddress,
        uint256 tokenId
    ) external returns (address) {
        NftAuction auction = new NftAuction();
        auction.initialize(
            msg.sender,
            duration,
            startPrice,
            nftContractAddress,
            tokenId
        );
        auctions.push(address(auction));
        auctionMap[tokenId] = auction;

        emit AuctionCreated(address(auction), tokenId);
        return address(auction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getAuction(uint256 tokenId) external view returns (address) {
        require(tokenId < auctions.length, "tokenId out of bounds");
        return auctions[tokenId];
    }
}
