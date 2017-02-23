pragma solidity ^0.4.6;

import "GithubOraclizeParser.sol";
import "GithubOraclize.sol";
import "Collateralize.sol";
import "ClaimableBounty.sol";

contract Repository is GithubOraclize, Collateralize, ClaimableBounty {
  using GithubOraclizeParser for string;

  struct Issue {
    string url;
    uint bounty;
    bool initialized;
  }

  struct PullRequest {
    string url;
    address owner;
    Issue issue;
    bool initialized;
  }

  string public url;
  uint public maintainerFeeNum;
  uint public maintainerFeeDenom;

  string[] public issueUrls;

  mapping(address => bool) public maintainers;
  mapping(string => Issue) issues; // issue url => Issue
  mapping(string => PullRequest) activePullRequests; // pull request url => PullRequest

  event OpenedPullRequestSuccess(address claimant, string url);
  event OpenedPullRequestFailed(address claimant, string url, uint updatedCollateral);
  event MergedPullRequestSuccess(address claimant, string url, uint devBounty, uint maintainerFee);
  event MergedPullRequestFailed(address claimant, string url, uint updatedCollateral);
  event IssueSuccess(address claimant, string url, uint bounty);
  event IssueFailed(address claimant, string url);

  modifier onlyMaintainers() {
    if (!maintainers[msg.sender]) throw;
    _;
  }

  modifier issueExists(string issueUrl) {
    if (!issues[issueUrl].initialized) throw;
    _;
  }

  modifier pullRequestExists(string prUrl) {
    if (!activePullRequests[prUrl].initialized) throw;
    _;
  }

  function Repository(string _url, address[] _maintainers, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _maintainerFeeNum, uint _maintainerFeeDenom, uint _oraclizeGas) {
    /* OAR = OraclizeAddrResolverI(0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475); */

    url = _url;

    for (uint i = 0; i < _maintainers.length; i++) {
      maintainers[_maintainers[i]] = true;
    }

    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    maintainerFeeNum = _maintainerFeeNum;
    maintainerFeeDenom = _maintainerFeeDenom;
    oraclizeGas = _oraclizeGas;
  }

  /* User transactions */

  function openPullRequest(string jsonHelper, string url, string issueUrl) requiresCollateral issueExists(issueUrl) payable {
    collaterals[msg.sender] = msg.value;

    // jsonHelper format: json(url).[issue_url, body]
    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, url, OraclizeQueryType.VerifyOpenedPullRequest);
    collaterals[msg.sender] -= oraclizeFee;

    activePullRequests[url] = PullRequest(url, msg.sender, issues[issueUrl], false);
  }

  function mergePullRequest(string jsonHelper, string url) onlyMaintainers requiresCollateral pullRequestExists(url) payable {
    collaterals[msg.sender] = msg.value;

    // jsonHelper format: json(url).merged
    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, url, OraclizeQueryType.VerifyMergedPullRequest);
    collaterals[msg.sender] -= oraclizeFee;
  }

  function fundIssue(string jsonHelper, string url) payable {
    if (!issues[url].initialized) {
      // jsonHelper format: json(url).url
      uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, url, OraclizeQueryType.VerifyIssue);

      issues[url] = Issue(url, msg.value - oraclizeFee, false);
    } else {
      // Issue already exists - don't need oraclize
      issues[url].bounty += msg.value;
    }
  }

  /* Callbacks */

  function __callback(bytes32 queryId, string result) onlyOraclize {
    OraclizeCallback memory c = oraclizeCallbacks[queryId];

    if (c.queryType == OraclizeQueryType.VerifyOpenedPullRequest) {
      verifyOpenedPullRequestCallback(c.claimant, c.url, result);
    } else if (c.queryType == OraclizeQueryType.VerifyMergedPullRequest) {
      verifyMergedPullRequestCallback(c.claimant, c.url, result);
    } else if (c.queryType == OraclizeQueryType.VerifyIssue) {
      verifyIssueCallback(c.claimant, c.url, result);
    } else {
      // Unknown query
      throw;
    }
  }

  function verifyOpenedPullRequestCallback(address claimant, string url, string result) internal {
    if (!result.isValid()) {
      verifyOpenedPullRequestFailedCallback(claimant, url);
    } else {
      verifyOpenedPullRequestSuccessCallback(claimant, url, result);
    }
  }

  function verifyMergedPullRequestCallback(address claimant, string url, string result) internal {
    if (!result.isValid() || result.isFalse()) {
      verifyMergedPullRequestFailedCallback(claimant, url);
    } else {
      verifyMergedPullRequestSuccessCallback(claimant, url, result);
    }
  }

  function verifyIssueCallback(address claimant, string url, string result) internal {
    if (!result.isValid()) {
      verifyIssueFailedCallback(claimant, url);
    } else {
      verifyIssueSuccessCallback(claimant, url, result);
    }
  }

  function verifyOpenedPullRequestSuccessCallback(address claimant, string url, string result) internal {
    if (!result.checkPullRequest(claimant, activePullRequests[url].issue.url)) {
      verifyOpenedPullRequestFailedCallback(claimant, url);
    } else {
      activePullRequests[url].initialized = true;

      OpenedPullRequestSuccess(claimant, url);
    }
  }

  function verifyOpenedPullRequestFailedCallback(address claimant, string url) internal {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    delete activePullRequests[url];

    OpenedPullRequestFailed(claimant, url, collaterals[claimant]);
  }

  function verifyMergedPullRequestSuccessCallback(address claimant, string url, string result) internal {
    uint bounty = activePullRequests[url].issue.bounty;
    uint maintainerFee = calcMaintainerFee(bounty);
    uint devBounty = bounty - maintainerFee;

    claimableBounties[claimant] += maintainerFee;
    claimableBounties[activePullRequests[url].owner] += devBounty;

    delete activePullRequests[url];

    MergedPullRequestSuccess(claimant, url, devBounty, maintainerFee);
  }

  function verifyMergedPullRequestFailedCallback(address claimant, string url) internal {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    MergedPullRequestFailed(claimant, url, collaterals[claimant]);
  }

  function verifyIssueSuccessCallback(address claimant, string url, string result) internal {
    issues[url].initialized = true;
    issueUrls.push(url);

    IssueSuccess(claimant, url, issues[url].bounty);
  }

  function verifyIssueFailedCallback(address claimant, string url) internal {
    delete issues[url];

    IssueFailed(claimant, url);
  }

  /* Utils */

  function getIssueCount() public constant returns (uint) {
    return issueUrls.length;
  }

  function getIssueByUrl(string url) public constant returns (string, uint, bool) {
    return (issues[url].url, issues[url].bounty, issues[url].initialized);
  }

  function getPullRequestByUrl(string url) public constant returns (string, string) {
    return (activePullRequests[url].url, activePullRequests[url].issue.url);
  }

  function setMaintainerFee(uint _maintainerFeeNum, uint _maintainerFeeDenom) onlyMaintainers {
    maintainerFeeNum = _maintainerFeeNum;
    maintainerFeeDenom = _maintainerFeeDenom;
  }

  function calcMaintainerFee(uint amount) internal constant returns (uint) {
    return (amount * maintainerFeeNum) / maintainerFeeDenom;
  }

}
