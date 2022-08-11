// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

error IndexOutOfRange();
error InvalidAction();
error OnlyOwnerOrStaking();
error UnapprovedRecipient();
error UpdateFailed();

contract Gum is ERC20, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private _transferAllowList;
    address public staking;

    enum TransferAllowListAction {
        Add,
        Remove
    }

    event TransferAllowListUpdated(
        address _approvedAddress,
        TransferAllowListAction _action
    );
    event StakingUpdated(address _staking);

    constructor(address _staking) ERC20("Gum", "GUM") {
        staking = _staking;
    }

    modifier onlyOwnerOrStaking() {
        if (msg.sender != owner() && msg.sender != staking) {
            revert OnlyOwnerOrStaking();
        }
        _;
    }

    /**
     * @dev Add or remove an item from the list of addresses to which
     * GUM can be transfered.
     * @param _address The address to add or remove from the allow list
     * @param _action 0 to add, 1 to remove
     */
    function updateTransferAllowList(address _address, uint8 _action)
        public
        onlyOwner
    {
        if (_action > 1) revert InvalidAction();
        bool success;
        if (_action == 0) {
            success = EnumerableSet.add(_transferAllowList, _address);
        } else if (_action == 1) {
            success = EnumerableSet.remove(_transferAllowList, _address);
        }
        if (!success) revert UpdateFailed();
        TransferAllowListAction action = TransferAllowListAction(_action);
        emit TransferAllowListUpdated(_address, action);
    }

    function getTransferAllowListLength() public view returns (uint256) {
        return EnumerableSet.length(_transferAllowList);
    }

    function getTransferAllowListAtIndex(uint256 index)
        public
        view
        returns (address)
    {
        if (index >= EnumerableSet.length(_transferAllowList)) {
            revert IndexOutOfRange();
        }
        return EnumerableSet.at(_transferAllowList, index);
    }

    function updateStaking(address _staking) public onlyOwner {
        staking = _staking;
        emit StakingUpdated(_staking);
    }

    /**
     * @dev Only owner and staking contract can mint tokens.
     */
    function mint(address to, uint256 amount) public onlyOwnerOrStaking {
        _mint(to, amount);
    }

    /**
     * @dev Overwrite the transfer function so that GUM can only be sent
     * to approved addresses.
     */
    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        if (!EnumerableSet.contains(_transferAllowList, to)) {
            revert UnapprovedRecipient();
        }
        return ERC20.transfer(to, amount);
    }

    /**
     * @dev Overwrite the transferFrom function so that GUM can only be
     * sent to approved addresses.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (!EnumerableSet.contains(_transferAllowList, to)) {
            revert UnapprovedRecipient();
        }
        return ERC20.transferFrom(from, to, amount);
    }
}
