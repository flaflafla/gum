// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DummyERC721 is ERC721 {
    uint256 public nextTokenId = 0;

    constructor() ERC721("DummyERC721", "DUM721") {}

    function mint(address to, uint256 count) public {
        for (uint256 i = 0; i < count; i++) {
            _safeMint(to, nextTokenId);
            nextTokenId++;
        }
    }
}
