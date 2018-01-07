pragma solidity ^0.4.8;

contract RockPaperScissors {
	address public owner;

	function RockPaperScissors() {
		owner = msg.sender;
	}

}