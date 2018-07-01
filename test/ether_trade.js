var EtherTrader = artifacts.require("EtherTrader");
var EToken = artifacts.require("EnEToken");
var web3 = require('web3');


contract('EToken', function(accounts) {

	it('EToken create', function() {
		EToken.deployed().then((instance) => {
			instance.setAdmin(account(0)).then(() => {
				instance.create(accounts[0], web3.toWei(500000, 'ether'));
			});
		});
	});


});


contract('EtherTrader', function(accounts) {
	it("deposit", function() {
		EtherTrader.deployed().then((instance) => {
			instance.depositToken( web3.toWei(30000, 'ether'))
		});
	});


});


