pragma solidity ^0.4.6;

import "strings.sol";
import "Collateralize.sol";
import "GithubOraclize.sol";
import "GithubOraclizeParser.sol";
import "Repository.sol";

contract DevBounty is GithubOraclize, Collateralize {
  using strings for *;
  using GithubOraclizeParser for string;
  using Repository for Repository.Repo;

  string[] public repositoryUrls;

  mapping(string => Repository.Repo) repositories;

  // EVENTS
  event MaintainerSuccess(address claimant, string repoUrl, string apiUrl);
  event MaintainerFailed(address claimant, string repoUrl, string apiUrl);
  event IssueSuccess(address claimant, string repoUrl, string apiUrl, uint bounty);
  event IssueFailed(address claimant, string repoUrl, string apiUrl);
  event OpenedPullRequestSuccess(address claimant, string repoUrl, string apiUrl);
  event OpenedPullRequestFailed(address claimant, string repoUrl, string apiUrl);
  event MergedPullRequestSuccess(address claimant, string repoUrl, string apiUrl);
  event MergedPullRequestFailed(address claimant, string repoUrl, string apiUrl);

  // MODIFIERS

  modifier onlyMaintainers(string repoUrl) {
    if (!repositories[repoUrl].hasMaintainer(msg.sender)) throw;
    _;
  }

  modifier repositoryExists(string repoUrl) {
    if (!repositories[repoUrl].initialized) throw;
    _;
  }

  modifier requiresRepoCollateral(string repoUrl) {
    if (msg.value < repositories[repoUrl].minCollateral) throw;
    _;
  }

  function DevBounty(uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    OAR = OraclizeAddrResolverI(0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475);

    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    oraclizeGas = _oraclizeGas;
  }

  // EXTERNAL

  function registerRepository(string jsonHelper, string repoUrl, string proofUrl, uint minCollateral, uint penaltyNum, uint penaltyDenom, uint maintainerFeeNum, uint maintainerFeeDenom) requiresCollateral payable {
    // jsonHelper format: json(url).url
    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, repoUrl, proofUrl, OraclizeQueryType.VerifyMaintainer);

    collaterals[msg.sender] += msg.value - oraclizeFee;

    repositories[repoUrl].url = repoUrl;
    repositories[repoUrl].minCollateral = minCollateral;
    repositories[repoUrl].penaltyNum = penaltyNum;
    repositories[repoUrl].penaltyDenom = penaltyDenom;
    repositories[repoUrl].maintainerFeeNum = maintainerFeeNum;
    repositories[repoUrl].maintainerFeeDenom = maintainerFeeDenom;
    repositories[repoUrl].initialized = false;
  }

  function fundIssue(string jsonHelper, string repoUrl, string issueUrl) repositoryExists(repoUrl) payable {
    if (!repositories[repoUrl].issueExists(issueUrl)) {
      // jsonHelper format: json(url).url
      uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, repoUrl, issueUrl, OraclizeQueryType.VerifyIssue);

      repositories[repoUrl].createIssue(issueUrl, msg.value - oraclizeFee);
    } else {
      repositories[repoUrl].updateIssueBounty(issueUrl, msg.value);
    }
  }

  function openPullRequest(string jsonHelper, string repoUrl, string prUrl, string issueUrl) repositoryExists(repoUrl) requiresRepoCollateral(repoUrl) payable {
    if (!repositories[repoUrl].issueExists(issueUrl)) throw;

    // jsonHelper format: json(url).[issue_url, body]
    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, repoUrl, prUrl, OraclizeQueryType.VerifyOpenedPullRequest);

    collaterals[msg.sender] += msg.value - oraclizeFee;

    repositories[repoUrl].createPullRequest(prUrl, msg.sender, issueUrl);
  }

  function mergePullRequest(string jsonHelper, string repoUrl, string prUrl) repositoryExists(repoUrl) requiresRepoCollateral(repoUrl) onlyMaintainers(repoUrl) payable {
    if (!repositories[repoUrl].pullRequestExists(prUrl)) throw;

    // jsonHelper format: json(url).merged
    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, repoUrl, prUrl, OraclizeQueryType.VerifyMergedPullRequest);

    collaterals[msg.sender] += msg.value - oraclizeFee;
  }

  // CALLBACKS

  function __callback(bytes32 queryId, string result) onlyOraclize {
    OraclizeCallback memory c = oraclizeCallbacks[queryId];

    if (c.queryType == OraclizeQueryType.VerifyMaintainer) {
      verifyMaintainerCallback(c.claimant, c.repoUrl, c.apiUrl, result);
    } else if (c.queryType == OraclizeQueryType.VerifyOpenedPullRequest) {
      verifyOpenedPullRequestCallback(c.claimant, c.repoUrl, c.apiUrl, result);
    } else if (c.queryType == OraclizeQueryType.VerifyMergedPullRequest) {
      verifyMergedPullRequestCallback(c.claimant, c.repoUrl, c.apiUrl, result);
    } else if (c.queryType == OraclizeQueryType.VerifyIssue) {
      verifyIssueCallback(c.claimant, c.repoUrl, c.apiUrl, result);
    } else {
      // Unknown query
      throw;
    }
  }

  function verifyMaintainerCallback(address claimant, string repoUrl, string proofUrl, string result) internal {
    /* Expect PROOF.md contents to be of the following form: */
    /* <addr>\n<addr>... */
    var contents = result.toSlice();
    var delim = "\n".toSlice();
    var maintainers = new address[](contents.count(delim));

    bool verified = false;

    for (uint i = 0; i < maintainers.length; i++) {
      maintainers[i] = parseAddr(contents.split(delim).toString());

      if (maintainers[i] == claimant) verified = true;
    }

    if (!verified) {
      penalize(claimant);

      delete repositories[repoUrl];

      MaintainerSuccess(claimant, repoUrl, proofUrl);
    } else {
      repositories[repoUrl].initialized = true;

      for (uint j = 0; j < maintainers.length; j++) {
        repositories[repoUrl].maintainers[maintainers[j]] = true;
      }

      repositoryUrls.push(repoUrl);

      MaintainerSuccess(claimant, repoUrl, proofUrl);
    }
  }

  function verifyIssueCallback(address claimant, string repoUrl, string issueUrl, string result) internal {
    if (!result.isValid()) {
      repositories[repoUrl].deleteIssue(issueUrl);

      IssueFailed(claimant, repoUrl, issueUrl);
    } else {
      repositories[repoUrl].initIssue(issueUrl);

      IssueSuccess(claimant, repoUrl, issueUrl, repositories[repoUrl].issues[issueUrl].bounty);
    }
  }

  function verifyOpenedPullRequestCallback(address claimant, string repoUrl, string prUrl, string result) internal {
    if (!result.isValid() || !result.checkPullRequest(claimant, repositories[repoUrl].pullRequests[prUrl].issue.url)) {
      penalize(claimant);
      repositories[repoUrl].deletePullRequest(prUrl);

      OpenedPullRequestFailed(claimant, repoUrl, prUrl);
    } else {
      repositories[repoUrl].initPullRequest(prUrl);

      OpenedPullRequestSuccess(claimant, repoUrl, prUrl);
    }
  }

  function verifyMergedPullRequestCallback(address claimant, string repoUrl, string prUrl, string result) internal {
    if (!result.isValid() || result.isFalse()) {
      penalize(claimant);

      MergedPullRequestFailed(claimant, repoUrl, prUrl);
    } else {
      repositories[repoUrl].computeBounties(claimant, prUrl);
      repositories[repoUrl].deletePullRequest(prUrl);

      MergedPullRequestSuccess(claimant, repoUrl, prUrl);
    }
  }

  // UTILITY

  function claimBounty(string repoUrl) external {
    address payee = msg.sender;

    uint bounty = repositories[repoUrl].claimableBounties[payee];

    if (bounty == 0) throw;
    if (this.balance < bounty) throw;

    repositories[repoUrl].claimableBounties[payee] = 0;
    if (!payee.send(bounty)) {
      repositories[repoUrl].claimableBounties[payee] = bounty;
    }
  }

  function addMaintainer(string repoUrl, address addr) onlyMaintainers(repoUrl) {
    repositories[repoUrl].addMaintainer(addr);
  }

  function setMaintainerFee(string repoUrl, uint maintainerFeeNum, uint maintainerFeeDenom) onlyMaintainers(repoUrl) {
    repositories[repoUrl].setMaintainerFee(maintainerFeeNum, maintainerFeeDenom);
  }

  function getIssueByUrl(string repoUrl, string issueUrl) public constant returns (uint, bool) {
    return repositories[repoUrl].getIssueByUrl(issueUrl);
  }

  function getPullRequestByUrl(string repoUrl, string prUrl) public constant returns (address, string, bool) {
    return (repositories[repoUrl].pullRequests[prUrl].owner, repositories[repoUrl].pullRequests[prUrl].issue.url, repositories[repoUrl].pullRequests[prUrl].initialized);
  }

}
