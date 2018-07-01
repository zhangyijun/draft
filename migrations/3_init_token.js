//var dex = artifacts.require("EtherTrader");
var etoken = artifacts.require("EnEToken");

module.exports = function(deployer, network, accounts) {
	console.log(accounts[0]);
  deployer.deploy(etoken, accounts[1]);

/*
  */
};
