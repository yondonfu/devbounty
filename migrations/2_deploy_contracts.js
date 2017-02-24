module.exports = function(deployer) {
  deployer.deploy(usingOraclize);
  deployer.deploy(Collateralize);
  deployer.deploy(GithubOraclize);
  deployer.deploy(GithubOraclizeParser);
  deployer.deploy(Repository);
  deployer.link(GithubOraclizeParser, DevBounty);
  deployer.link(Repository, DevBounty);
};
