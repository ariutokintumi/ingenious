// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EIP1155IPP is ERC1155, Ownable {
    using SafeMath for uint256;

    struct Metadata {
        string title;
        string technicalField;
        string background;
        string briefDescriptionOfDrawings;
        string detailedDescription;
        string references;
        string methods;
        bool isPatented;
        uint256 multiplier;
    }

    mapping(uint256 => Metadata) public tokenMetadata;
    mapping(uint256 => address) public tokenCreators;

    uint256 public constant DEFAULT_CREATOR_FEE_PERCENT = 1;  // 1%
    mapping(uint256 => uint256) public minimumTransferFees;  // Minimum transfer fee for each token

    event MetadataUpdated(uint256 indexed tokenId, Metadata metadata);
    event PatentStatusChanged(uint256 indexed tokenId, bool isPatented);
    event CreatorFeePaid(uint256 indexed tokenId, address indexed creator, uint256 amount);

    constructor() ERC1155("https://yourapi.com/api/item/{id}.json") {}

    function mint(
        address account, 
        uint256 id, 
        uint256 amount, 
        bytes memory data, 
        Metadata memory metadata,
        uint256 minimumTransferFee,
        uint256 multiplier
    )
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
        metadata.multiplier = multiplier;
        tokenMetadata[id] = metadata;
        tokenCreators[id] = msg.sender;
        minimumTransferFees[id] = minimumTransferFee;
        emit MetadataUpdated(id, metadata);
    }

    function setPatentStatus(uint256 tokenId, bool isPatented) public onlyOwner {
        Metadata storage metadata = tokenMetadata[tokenId];
        require(!metadata.isPatented, "Patent status is already set or unchanged");

        metadata.isPatented = isPatented;
        if (isPatented) {
            uint256 multiplier = metadata.multiplier;
            uint256 totalSupply = totalSupply(tokenId);
            uint256 newTotalSupply = totalSupply.mul(multiplier);
            _mint(msg.sender, tokenId, newTotalSupply.sub(totalSupply), "");
        }

        emit PatentStatusChanged(tokenId, isPatented);
    }

    function _beforeTokenTransfer(
        address operator, 
        address from, 
        address to, 
        uint256[] memory ids, 
        uint256[] memory amounts, 
        bytes memory data
    )
        internal
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0)) {
            for (uint i = 0; i < ids.length; i++) {
                uint256 tokenId = ids[i];
                require(msg.value >= minimumTransferFees[tokenId], "Transfer fee below required minimum");

                address creator = tokenCreators[tokenId];
                if (creator != address(0) && creator != to) {
                    uint256 creatorFee = msg.value * DEFAULT_CREATOR_FEE_PERCENT / 100;
                    payable(creator).transfer(creatorFee);
                    emit CreatorFeePaid(tokenId, creator, creatorFee);
                }
            }
       
