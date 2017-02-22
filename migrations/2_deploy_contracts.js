module.exports = function(deployer) {
  deployer.deploy(usingOraclize);
  deployer.deploy(Collateralize);
  deployer.deploy(ClaimableBounty);
  deployer.deploy(GithubOraclize);
  deployer.deploy(GithubOraclizeParser);
  deployer.link(GithubOraclizeParser, [DevBounty, Repository]);
};
