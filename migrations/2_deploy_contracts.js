module.exports = function(deployer) {
  deployer.deploy(usingOraclize);
  deployer.deploy(DevBounty, 1, 15, 100, 250000);
};
