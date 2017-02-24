module.exports = function(deployer) {
  deployer.deploy(usingOraclize);
  deployer.deploy(Collateralize);
  deployer.deploy(GithubOraclize);
  deployer.deploy(GithubOraclizeParser);
  deployer.deploy(Repository);
  deployer.deploy(DevBounty, 1, 15, 100, 250000, {gas: 6000000});
  deployer.link(GithubOraclizeParser, DevBounty);
  deployer.link(Repository, DevBounty);
};
