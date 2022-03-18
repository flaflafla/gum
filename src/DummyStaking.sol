// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IGum {
    function mint(address, uint256) external;
}

/**
 * Dead-simple contract deployed to kovan at
 * 0xf68bc6789a3990899f123d3fd0e49df1f4902275. Used to test ability
 * of owner to call staking reward function, and staking contract
 * to mint GUM to recipient. Which works:
 * 0x31cbf94d3075ee8cb1389f93a601d49606b1f1859764588d12b0fd6de38e869f
 */
contract DummyStaking is Ownable {
    address public gumToken;

    event GumTokenUpdated(address _gumToken);

    constructor(address _gumToken) {
        gumToken = _gumToken;
    }

    function updateGumToken(address _gumToken) public onlyOwner {
        gumToken = _gumToken;
        emit GumTokenUpdated(_gumToken);
    }

    /**
     * @dev Mint GUM to rewards recipient.
     */
    function reward(address to, uint256 amount) public onlyOwner {
        IGum(gumToken).mint(to, amount);
    }
}
