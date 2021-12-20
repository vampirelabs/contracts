// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NightWorld is ERC721Enumerable, Ownable {
  using Strings for uint256;

  uint256 public NW_PRESALE = 1000;
  uint256 public NW_PUBLIC = 9894;
  uint256 public NW_MAX = NW_PRESALE + NW_PUBLIC;
  uint256 public PURCHASE_LIMIT = 10;
  uint256 public PRICE = 0.07 ether;

  bool public _PreSaleOpen = false;
  bool public _PubSaleOpen = false;
  
  uint256 public _CurrPreSupply;
  uint256 public _CurrPubSupply;

  uint256 public _rewardAmount = 1 ether;
  uint256 public _rewardGap = 100;

  mapping(address => uint256) private _WhilteList;
  address[] private _rewardList;

  string public _contractURI = '';
  string public _tokenBaseURI = '';
  string public _tokenPreSaleURI = '';
  string public _tokenPubSaleURI = '';
  address public _signAddress;

  constructor() ERC721("Night World Token", "NWT") {}
  
  function setSignAddress(address signAddress) external onlyOwner {
    _signAddress = signAddress;
  }

  function openPresale() external onlyOwner {
    _PreSaleOpen = true;
  }

  function openPubsale() external onlyOwner {
    _PubSaleOpen = true;
  }

  function getSaleInfo() external view returns(uint256, uint256) {
    return(_CurrPreSupply, _CurrPubSupply);
  }

  function getPresaleInfo() external view returns (uint256 current, uint256 total) {
    return(_CurrPreSupply, NW_PRESALE);
  }

  function getPubsaleInfo() external view returns (uint256 current, uint256 total) {
    return(_CurrPubSupply, NW_PUBLIC);
  }

  function queryRewardList(uint256 start) external view returns (address[32] memory result) {
    if (start >= _rewardList.length) {
      return result;
    }

    for (uint256 i=0; i<32; ++i) {
      if (start + i >= _rewardList.length) {
        return result;
      }

      result[i] = _rewardList[start + i];
    }
  }

  function addWL(address[] calldata addresses, uint256 disCount) external onlyOwner {
    require(0 < disCount && disCount<= 101, 'disCount err');

    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Can't add the null address");
      _WhilteList[addresses[i]] = disCount;
    }
  }

  function checkWL(address addr) external view returns (bool isExist, uint256 discount) {
      discount = _WhilteList[addr];
      if (discount == 101) {
          return (true, 0);
      }

      return discount == 0 ? (false, 100) : (true, discount);
  }

  function mintWL(uint256 numberOfTokens, bytes memory signature) external payable {
    require(numberOfTokens > 0, 'numberOfTokens err');
    require(_PreSaleOpen, 'Contract is not active');
    require(numberOfTokens <= PURCHASE_LIMIT, 'Cannot purchase this many tokens');
    require(_CurrPreSupply + numberOfTokens <= NW_PRESALE, 'Purchase would exceed Limit');
    require(PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');
    require(checkSignatureWallet(msg.sender, signature), "WhiteList check err");

    uint256 discount = _WhilteList[msg.sender];
    if (discount == 101) {
      uint256 tokenId = ++_CurrPreSupply;

      _safeMint(msg.sender, tokenId);
      payable(msg.sender).transfer(PRICE);

      --numberOfTokens;
      _WhilteList[msg.sender] = 100;

      if (_CurrPreSupply % _rewardGap == 0) {
        uint256 random = _getRandom(string(abi.encodePacked("Reward", block.number.toString(), uint256(uint160(msg.sender)).toString()))) % 100 + 1;
        address rewardOwner = ownerOf(tokenId - _rewardGap + random);
        payable(rewardOwner).transfer(_rewardAmount);
        _rewardList.push(rewardOwner);
      }
    }

    for (uint256 i = 0; i < numberOfTokens; i++) {
      uint256 tokenId = ++_CurrPreSupply;
      _safeMint(msg.sender, tokenId);

      if (_CurrPreSupply % _rewardGap == 0) {
        uint256 random = _getRandom(string(abi.encodePacked("Reward", block.number.toString(), uint256(uint160(msg.sender)).toString()))) % 100 + 1;
        address rewardOwner = ownerOf(tokenId - _rewardGap + random);
        payable(rewardOwner).transfer(_rewardAmount);
        _rewardList.push(rewardOwner);
      }
    }
  }

  function mint(uint256 numberOfTokens) external payable {
    require(numberOfTokens > 0, 'numberOfTokens err.');
    require(_PubSaleOpen, 'Contract is not active');
    require(numberOfTokens <= PURCHASE_LIMIT, 'Would exceed PURCHASE_LIMIT');
    require(_CurrPubSupply + numberOfTokens < NW_PUBLIC, 'Purchase would exceed NW_PUBLIC');
    require(PRICE * numberOfTokens <= msg.value, 'ETH amount is not sufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      uint256 tokenId = NW_PRESALE + _CurrPubSupply + 1;

      _safeMint(msg.sender, tokenId);
      ++_CurrPubSupply;

      if (_CurrPubSupply % _rewardGap == 0) {
        uint256 random = _getRandom(string(abi.encodePacked("Reward", block.number.toString(), uint256(uint160(msg.sender)).toString()))) % 100 + 1;
        address rewardOwner = ownerOf(tokenId - _rewardGap + random);
        payable(rewardOwner).transfer(_rewardAmount);
        _rewardList.push(rewardOwner);
      }
    }
  }

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function setContractURI(string calldata URI) external onlyOwner {
    _contractURI = URI;
  }

  function setBaseURI(string calldata URI) external onlyOwner {
    _tokenBaseURI = URI;
  }

  function setPreSaleURI(string calldata URI) external onlyOwner {
    _tokenPreSaleURI = URI;
  }

  function setPubSaleBaseURI(string calldata URI) external onlyOwner {
    _tokenPubSaleURI = URI;
  }

  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
    require(_exists(tokenId), 'Token does not exist');

    if (tokenId <= NW_PRESALE) {
      return bytes(_tokenPreSaleURI).length > 0 ? string(abi.encodePacked(_tokenPreSaleURI, tokenId.toString())) : _tokenBaseURI;
    } else {
      return bytes(_tokenPubSaleURI).length > 0 ? string(abi.encodePacked(_tokenPubSaleURI, tokenId.toString())) : _tokenBaseURI;
    }
  }

  function _getRandom(string memory purpose) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.timestamp, tx.gasprice, purpose)));
  }

  function checkSignatureWallet(address wallet, bytes memory signature) public view returns (bool) {
    return _signAddress == ECDSA.recover(keccak256(abi.encode(wallet)), signature);
  }
}
