// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./ERC721A.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./MerkleProof.sol";

    /*///////////////////////////////////////////////////////////////
                             __          _     
                       __ _ / _|_      _| |__  
                      / _` | |_\ \ /\ / / '_ \ 
                     | (_| |  _|\ V  V /| | | |
                      \__,_|_|   \_/\_/ |_| |_|
                      
    //////////////////////////////////////////////////////////////*/

contract MyNFTContract is ERC721A, Ownable, ReentrancyGuard {

    mapping(address => uint256) public whitelistMintCounter;

    uint256 public constant whitelistMintLimit = 2;
    uint256 public constant transactionLimit = 2;
    uint256 public constant reservedLimit = 100;
    uint256 public constant maxSupply = 6000;
    uint256 public constant cost = 0.01 ether;
    uint256 public reservedCounter;

    bool public revealed = false;
    bool public mintState = false;
    bool public whitelistMintState = true;

    string private baseURI;
    string private previewURI;


    bytes32 private whitelistRootHash;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    constructor(string memory _initPreviewURI) ERC721A("NFT Name", "NFT Symbol"){
        previewURI = _initPreviewURI;
    }


    function tokenURI(uint256 tokenId) public view virtual override returns(string memory){
        require(_exists(tokenId), "ERC 721Metadata: URI query for nonexistent token");

        if(!revealed) {
            return previewURI;
        }

        string memory currentBaseURI = baseURI;
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, _toString(tokenId), ".json")): "";
    }


    /*///////////////////////////////////////////////////////////////
                            USER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function publicMint(uint256 _amount) external payable callerIsUser nonReentrant {
        require(mintState, "Mint is disabled");
        require(!whitelistMintState, "Only whitelisted addresses can mint");
        require(totalSupply() + _amount <= maxSupply, "Total supply exceeded");
        require(_amount <= transactionLimit, "Only 2 mints per transaction");

        require(msg.value == cost * _amount, "Insufficient funds");
        _mint(msg.sender, _amount);    


    }

    //Whitelist Mint
    function whitelistMint(bytes32[] calldata _merkleProof, uint256 _amount) external payable callerIsUser nonReentrant {
        require(mintState, "Mint is disabled");
        require(whitelistMintState, "Whitelist minting is already over");
        require(totalSupply() + _amount <= maxSupply, "Total supply exceeded");
        require(_amount <= transactionLimit, "Only 2 mints per transaction");

        require(whitelistMintCounter[msg.sender] + _amount <= whitelistMintLimit, "Whitelisted addresses are only entitled to 2 mints");

        //Verify wallet address is whitelisted
        require(MerkleProof.verify(_merkleProof, whitelistRootHash, keccak256(abi.encodePacked(msg.sender))), "Address is not whitelisted");

        require(msg.value == cost * _amount, "Insufficient funds");
        whitelistMintCounter[msg.sender] += _amount;
        _mint(msg.sender, _amount);
    }


    /*///////////////////////////////////////////////////////////////
                            ADMIN UTILITIES
    //////////////////////////////////////////////////////////////*/

    function reservedMint(uint256 _amount) external onlyOwner {
        require(totalSupply() + _amount <= maxSupply, "Total supply exceeded");
        require(reservedCounter + _amount <= reservedLimit, "Reserved limit exceeded");
        reservedCounter += _amount;
        _mint(msg.sender, _amount);
    }

    function setWhitelistRootHash(bytes32 _newWhitelistRootHash) external onlyOwner {
        whitelistRootHash = _newWhitelistRootHash;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner{
        baseURI = _newBaseURI;
    }

    function setPreviewURI(string memory _newPreviewURI) external onlyOwner {
        previewURI = _newPreviewURI;
    }

    function setMintState() external onlyOwner { 
        mintState = !mintState;
    }

    function setWhitelistMintState() external onlyOwner {
        whitelistMintState = !whitelistMintState;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }


    //Withdraw contract funds
    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }


}