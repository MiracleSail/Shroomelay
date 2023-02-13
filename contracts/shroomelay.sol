// SPDX-License-Identifier: MIT

//           ___..._
//      _,--'       "`-.
//    ,'.  .            \
//  ,/:. .     .       .'
//  |;..  .      _..--'
//  `--:...-,-'""\
//          |:.  `.
//          l;.   l
//          `|:.   |
//           |:.   `.,
//          .l;.    j, ,
//       `. \`;:.   //,/
//        .\\)`;,|\'/(
//         ` ```` `(,

pragma solidity >=0.8.0 <0.9.0;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "node_modules/@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "node_modules/@openzeppelin/contracts/utils/Strings.sol";

import "node_modules/erc721a/contracts/ERC721A.sol";

contract Shroomelay is ERC721A, Ownable {
    using Strings for uint256;

    enum ContractMintState {
        PAUSED,
        WHITELIST,
        PUBLIC
    }

    ContractMintState public state = ContractMintState.PAUSED;

    string public uriPrefix = "";
    string public hiddenMetadataUri = "ipfs://";

    uint256 public wlCost = 0.015 ether;
    uint256 public publicCost = 0.03 ether;
    uint256 public maxSupply = 5555;
    uint256 public maxMintAmountPerTx = 3;

    mapping (uint256 => bool) private rightLinks;

    bytes32 public whitelistMerkleRoot;

    constructor() ERC721A("Shroomelay", "SHROOMELAY") {}

    // OVERRIDES
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    // MODIFIERS
    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded"
        );
        _;
    }

    // MERKLE TREE
    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, whitelistMerkleRoot, leaf);
    }

    function _leaf(address account, uint256 allowance) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, allowance));
    }

    // LINKING
    function linkShroom(uint256 tokenId, bool right) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "You don't own this token");
        
        uint256 neighborId;
        if (right) {
            neighborId = rightNeighborId(tokenId);
            require(neighborId != 0, "No right neighbor");
        } else {
            neighborId = leftNeighborId(tokenId);
            require(neighborId != 0, "No left neighbor");
        }
        
        if (right) {
            rightLinks[tokenId] = true;
        } else {
            rightLinks[neighborId] = true;
        }
    }

    // MINTING FUNCTIONS
    function mint(uint256 amount) public payable mintCompliance(amount) {
        require(state == ContractMintState.PUBLIC, "Public mint is disabled");
        require(msg.value >= publicCost * amount, "Insufficient funds");

        _safeMint(msg.sender, amount);
    }

    function mintWhiteList(uint256 amount, uint256 allowance, bytes32[] calldata proof) public payable mintCompliance(amount) {
        require(
            state == ContractMintState.WHITELIST,
            "Whitelist mint is disabled"
        );
        require(
            numberMinted(msg.sender) + amount <= allowance,
            "Can't mint that many"
        );
        require(_verify(_leaf(msg.sender, allowance), proof), "Invalid proof");
        require(msg.value >= wlCost * amount, "Insufficient funds");

        _safeMint(msg.sender, amount);
    }

    function mintForAddress(uint256 amount, address _receiver) public onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        _safeMint(_receiver, amount);
    }

    // GETTERS
    function numberMinted(address _minter) public view returns (uint256) {
        return _numberMinted(_minter);
    }

    function leftNeighborId(uint256 _tokenId) public view returns (uint256) {
        uint256 neighborId;
        if (_exists(_tokenId)) {
            if (_tokenId == 1 && _exists(maxSupply)) { // Corner case
                    neighborId = maxSupply;
            } else {
                neighborId = _tokenId - 1;
            }
        }
        return neighborId;
    }

    function rightNeighborId(uint256 _tokenId) public view returns (uint256) {
        uint256 neighborId;
        if (_exists(_tokenId)) {
            if (_tokenId == maxSupply) {
                neighborId = 1;
            } else if (_exists(_tokenId + 1)) {
                neighborId = _tokenId + 1;
            }
        }
        return neighborId;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();

        uint256 ipfsId = _tokenId;
        uint256 rightId = rightNeighborId(_tokenId);
        uint256 leftId = leftNeighborId(_tokenId);

        if (rightId != 0 && rightLinks[_tokenId]) {
            ipfsId |= 0x10000;
        }
        
        if (leftId != 0 && rightLinks[leftId]) {
            ipfsId |= 0x20000;
        }

        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        ".json"
                    )
                )
                : hiddenMetadataUri;
    }

    // SETTERS
    function setState(ContractMintState _state) public onlyOwner {
        state = _state;
    }

    function setCosts(uint256 _publicCost) public onlyOwner {
        publicCost = _publicCost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setWhitelistMerkleRoot(bytes32 _whitelistMerkleRoot) external onlyOwner {
        whitelistMerkleRoot = _whitelistMerkleRoot;
    }

    // WITHDRAW
    function withdraw() public onlyOwner {
        bool success = true;

        (success, ) = payable(0x108dB270C4F05e49F5B5ac9ca87bdFBD19c5Eb44).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }
}