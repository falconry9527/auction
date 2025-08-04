// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "./NftAuction.sol";
contract NftAuctionFactory {
    address[] public auctions;
    mapping(string => address) public auctionsMapping; // 按卖家组织的拍卖
    event AuctionCreated(
        address indexed auction,
        address indexed seller,
        address nftContract,
        uint256 tokenId
    );

    // Create a new auction
    function createAuction(
        uint256 duration,
        uint256 startPrice,
        address nftContractAddress,
        uint256 tokenId,
        uint256 platformFeePercentage
    ) external returns (address) {
        NftAuction auction = new NftAuction();

        auction.initialize(duration, platformFeePercentage);

        address auctionAdrss = address(auction);
        auctions.push(auctionAdrss);
        string memory nftContractAddressAndtokenId = string(
            abi.encodePacked(
                toAsciiString(nftContractAddress),
                "_",
                uint2str(tokenId)
            )
        );
        auctionsMapping[nftContractAddressAndtokenId] = auctionAdrss;
        emit AuctionCreated(
            auctionAdrss,
            msg.sender,
            nftContractAddress,
            tokenId
        );
        return address(auction);
    }

    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getAuction(
        string nftContractAndtokenId
    ) external view returns (address) {
        return auctionsMapping[nftContractAndtokenId];
    }

    // Helper function to convert address to string
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // Helper function to convert uint to string
    function uint2str(uint _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }
}
