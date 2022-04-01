// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Staking.sol";

interface CheatCodes {
    function prank(address) external;
}

contract GumTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Staking stakingContract;

    address GUM_TOKEN = address(1);
    address USER_ADDRESS = address(2);

    function setUp() public {
        stakingContract = new Staking(GUM_TOKEN);
    }

    // function testDeposit() public {
    //     stakingContract.start();
    //     cheats.prank(USER_ADDRESS);
    //     uint256[] memory tokenIds = new uint256[](3);
    //     tokenIds[0] = 1;
    //     tokenIds[1] = 2;
    //     tokenIds[2] = 3;
    //     stakingContract.deposit(tokenIds);
    // }
}
