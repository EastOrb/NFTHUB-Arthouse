// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract NFTHUB is ReentrancyGuard, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;

    address payable private _owner;
    uint256 private _listingPrice = 1;
    IERC20 private _celoUSD;

    constructor(address celoUSDAddress) ERC721("NFTHUB", "NFTH") {
        _owner = payable(msg.sender);
        _celoUSD = IERC20(celoUSDAddress);
    }

    struct Item {
        uint256 id;
        address minter;
        address nftAddress;
        uint256 tokenId;
        string tokenURI;
    }

    mapping(uint256 => Item) private _idToItem;
    uint256[] private _itemIdsArray;

    event ItemListed(uint256 indexed id, string tokenURI);

    modifier onlyOwnerOrApproved(address nftAddress, uint256 tokenId) {
        require(
            msg.sender == _owner || _isApprovedOrOwner(nftAddress, tokenId),
            "Only owner or approved address can call this function"
        );
        _;
    }

    function _isApprovedOrOwner(address nftAddress, uint256 tokenId)
        private
        view
        returns (bool)
    {
        return
            _exists(tokenId) &&
            (ERC721(nftAddress).ownerOf(tokenId) == msg.sender ||
                ERC721(nftAddress).getApproved(tokenId) == msg.sender ||
                ERC721(nftAddress).isApprovedForAll(
                    ERC721(nftAddress).ownerOf(tokenId),
                    msg.sender
                ));
    }

    function listNFT(address nftAddress, uint256 tokenId, string memory tokenURI)
        public
        payable
        nonReentrant
    {
        require(msg.value >= _listingPrice, "Listing price not met");

        _tokenIds.increment();
        uint256 newItemId = _itemIds.current();

        // Mint the NFT
        ERC721(nftAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        _safeMint(address(this), newItemId);
        _setTokenURI(newItemId, tokenURI);

        Item memory newItem = Item(
            newItemId,
            msg.sender,
            nftAddress,
            tokenId,
            tokenURI
        );
        _idToItem[newItemId] = newItem;
        _itemIdsArray.push(newItemId);

        emit ItemListed(newItemId, tokenURI);
        _owner.transfer(_listingPrice);
    }

    function purchaseNFT(uint256 itemId)
        public
        payable
        nonReentrant
    {
        require(_idToItem[itemId].minter != address(0), "Item does not exist");

        Item memory item = _idToItem[itemId];
        require(msg.value >= _listingPrice, "Listing price not met");

        // Transfer cUSD from buyer to seller
        _celoUSD.transferFrom(msg.sender, item.minter, _listingPrice);

        // Transfer NFT from contract to buyer
        ERC721(item.nftAddress).safe
