module.exports = function(deployer) {
  deployer.deploy(usingOraclize);
  deployer.deploy(Collateralize);
  deployer.deploy(ClaimableBounty);
  deployer.deploy(GithubOraclizeParser);
  deployer.link(GithubOraclizeParser, [DevBounty, Repository]);
};
