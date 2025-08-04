// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
contract NftAuctionFactory {
    address[] public auctions;
    mapping(string => address) public auctionsMapping; // 按卖家组织的拍卖
    event AuctionCreated(address indexed auction, address indexed seller, address nftContract, uint256 tokenId);

    // Create a new auction
    function createAuction(
        uint256 duration,
        uint256 startPrice,
        address nftContractAddress,
        uint256 tokenId,
        uint256 platformFeePercentage
    ) external returns (address) {
        NftAuction auction = new NftAuction();

        auction.initialize(
            duration,
            platformFeePercentage
        );

        address auctionAdrss= address(auction) ;
        auctions.push(auctionAdrss);
        string nftContractAddressAndtokenId = nftContract+tokenId ;
        auctionsMapping[nftContractAddressAndtokenId]=auctionAdrss;
        emit AuctionCreated(auctionAdrss, msg.sender, nftContractAddress, tokenId);

        return address(auction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getAuction(string  nftContractAndtokenId ) external view returns (address) {
        return auctionsMapping[nftContractAndtokenId];
    }
}
