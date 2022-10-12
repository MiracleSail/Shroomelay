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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "erc721a/contracts/ERC721A.sol";

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

    uint256 public publicCost = 0.03 ether;
    uint256 public maxSupply = 5000;
    uint256 public maxMintAmountPerTx = 3;

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

    // MINTING FUNCTIONS
    function mint(uint256 amount) public payable mintCompliance(amount) {
        require(state == ContractMintState.PUBLIC, "Public mint is disabled");
        require(msg.value >= publicCost * amount, "Insufficient funds");

        _safeMint(msg.sender, amount);
    }

    function mintWhiteList(uint256 amount, uint256 allowance, bytes32[] calldata proof) public mintCompliance(amount) {
        require(
            state == ContractMintState.WHITELIST,
            "Whitelist mint is disabled"
        );
        require(
            numberMinted(msg.sender) + amount <= allowance,
            "Can't mint that many"
        );
        require(_verify(_leaf(msg.sender, allowance), proof), "Invalid proof");

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

    function leftNeighbor(uint256 _tokenId) public view returns (uint256, string memory) {
        uint256 neighborId;
        if (_tokenId == 1) {
            require(totalSupply() == maxSupply, "No left neighbor yet :(");
            neighborId = maxSupply;
        } else {
            neighborId = _tokenId - 1;
        }
        return (neighborId, tokenURI(neighborId));
    }

    function rightNeighbor(uint256 _tokenId) public view returns (uint256, string memory) {
        uint256 neighborId;
        require(totalSupply() > _tokenId || totalSupply() == maxSupply, "No right neighbor yet :(");
        if (_tokenId == maxSupply) {
            neighborId = 1;
        } else {
            neighborId = _tokenId + 1;
        }
        return (neighborId, tokenURI(neighborId));
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();

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