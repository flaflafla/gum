// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DummyERC20 is ERC20 {
    constructor() ERC20("DummyERC20", "DUM20") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
