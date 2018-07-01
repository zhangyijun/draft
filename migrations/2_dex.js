//var dex = artifacts.require("EtherTrader");
var dex = artifacts.require("EtherTrader");

module.exports = function(deployer, network, accounts) {
	//console.log(accounts[0]);
	//console.log(dex);
  var admin = accounts[0];
  var fee = accounts[1];

  const feeMake       = 500000000000000;    //0.05%
  const feeTake       = 2000000000000000;   //0.2%
  const matchRate     = 300000000000000000; //30%
  const matchGasRate  = 100000000000000000; //10%
  const gas = 1000000;
  deployer.deploy(dex, admin, fee, feeMake, feeTake, matchRate, matchGasRate);

/*
  */
};
