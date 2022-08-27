// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DummyERC1155 is ERC1155 {
    uint256 public nextTokenId = 0;

    constructor() ERC1155("lol_dumb_uri") {}

    function mint(address to, uint256 count) public {
        for (uint256 i = 0; i < count; i++) {
            _mint(to, nextTokenId, 5, '');
            nextTokenId++;
        }
    }
}
