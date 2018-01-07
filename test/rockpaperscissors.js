var rps = artifacts.require("./RockPaperScissors.sol");

contract("rps", function(accounts) {
	var rpsContract;
	var owner = accounts[0];
	var player1 = accounts[1];
	var palyer1 = accounts[2];
	var notInvited = accounts[3];

	beforeEach(function(){
		return rps.new({from: owner})
		.then(function(instance){
			rpsContract = instance;
		});
	});

	//constructor 
	it("should be owned by owner", function(){
		return rpsContract.owner()
		.then(function(_actualOwner){
			assert.strictEqual(_actualOwner, owner,"contract is not owned by owner"); 		
		});
	});
});