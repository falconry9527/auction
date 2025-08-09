// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";

contract NftAuctionFactory {
    mapping(address => mapping(address => address[])) public auctionsMapping; // 按卖家组织的拍卖
    //address1  nftContractAddress 拍卖的nft地址
    //address2  user address
    //address3  auction address

    event AuctionCreated(
        address indexed auction,
        address indexed seller,
        address nftContract,
        uint256 tokenId
    );

    // Create a new auction
    function createAuction(
        uint256 duration,
        // uint256 startPrice,
        address nftContractAddress,
        // uint256 tokenId,
        uint256 platformFeePercentage
    ) external returns (address) {
        NftAuction auction = new NftAuction();

        auction.initialize(duration, platformFeePercentage);
        address auctionAdrss = address(auction);

        address[] storage addresses = auctionsMapping[nftContractAddress][
            msg.sender
        ];
        addresses.push(auctionAdrss);
        auctionsMapping[nftContractAddress][msg.sender] = addresses;

        return address(auction);
    }

    function getAuction(
        address nftContract, address user
    ) external view returns (address[] memory) {
        return auctionsMapping[nftContract][user];
    }
}
