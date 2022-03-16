// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Gum is ERC20, Ownable {
    address public marketplace;
    address public staking;

    constructor(address _marketplace, address _staking) ERC20("Gum", "GUM") {
        marketplace = _marketplace;
        staking = _staking;
    }

    modifier onlyOwnerOrStaking() {
        require(msg.sender == owner() || msg.sender == staking);
        _;
    }

    function updateMarkeplace(address _marketplace) public onlyOwner {
        marketplace = _marketplace;
    }

    function updateStaking(address _staking) public onlyOwner {
        staking = _staking;
    }

    function mint(address to, uint256 amount) public onlyOwnerOrStaking {
        _mint(to, amount);
    }

    /**
     * @dev Overwrite the transfer function so that GUM can only be sent
     * to the marketplace.
     */
    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        require(to == marketplace, "can only send GUM to the marketplace");
        return ERC20.transfer(to, amount);
    }

    /**
     * @dev Overwrite the transferFrom function so that GUM can only be
     * sent to the marketplace.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to == marketplace, "can only send GUM to the marketplace");
        return ERC20.transferFrom(from, to, amount);
    }
}
