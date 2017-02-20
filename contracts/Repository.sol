pragma solidity ^0.4.6;

import "strings.sol";
import "GithubOraclize.sol";
import "Collateralize.sol";

contract Repository is GithubOraclize, Collateralize {
  using strings for *;

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
  mapping(address => uint) public claimableBounties; // developer address => claimable bounty amount

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

  function Repository(string _url, address[] _maintainers, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _maintainerFeeNum, uint _maintainerFeeDenom, uint _oraclizeGas) {
    OAR = OraclizeAddrResolverI(0x6f485c8bf6fc43ea212e93bbf8ce046c7f1cb475);

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

  function openPullRequest(string jsonHelper, string url, string issueUrl) requiresCollateral payable {
    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed jsonHelper - json(url).[issue_url, body]

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    activePullRequests[url] = PullRequest(url, msg.sender, issues[issueUrl], false);

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, OraclizeQueryType.VerifyOpenedPullRequest);
  }

  function mergePullRequest(string jsonHelper, string url) onlyMaintainers requiresCollateral payable {
    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed jsonHelper - json(url).merged

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, OraclizeQueryType.VerifyMergedPullRequest);
  }

  function fundIssue(string jsonHelper, string url) payable {
    if (!issues[url].initialized) {
      uint initialBalance = this.balance;

      bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed json helper - json(url).url

      uint updatedBalance = this.balance;
      uint oraclizeFee = initialBalance - updatedBalance;

      issues[url] = Issue(url, msg.value - oraclizeFee, false);

      oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, OraclizeQueryType.VerifyIssue);
    } else {
      // Issue already exists
      issues[url].bounty += msg.value;
    }
  }

  /* Post-verification operations */

  function verifyMaintainerSuccessCallback(address claimant, string url, address[] maintainers) {
    // Not needed for this contract
  }

  function verifyMaintainerFailedCallback(address claimant, string url) {
    // Not needed for this contract
  }

  function verifyOpenedPullRequestSuccessCallback(address claimant, string url, string result) {
    if (!checkPullRequest(claimant, url, result)) {
      verifyOpenedPullRequestFailedCallback(claimant, url);
    } else {
      activePullRequests[url].initialized = true;

      OpenedPullRequestSuccess(claimant, url);
    }
  }

  function verifyOpenedPullRequestFailedCallback(address claimant, string url) {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    delete activePullRequests[url];

    OpenedPullRequestFailed(claimant, url, collaterals[claimant]);
  }

  function verifyMergedPullRequestSuccessCallback(address claimant, string url, string result) {
    if (!activePullRequests[url].initialized) {
      verifyMergedPullRequestFailedCallback(claimant, url);
    } else {
      uint bounty = activePullRequests[url].issue.bounty;
      uint maintainerFee = calcMaintainerFee(bounty);
      uint devBounty = bounty - maintainerFee;

      claimableBounties[claimant] += maintainerFee;
      claimableBounties[activePullRequests[url].owner] += devBounty;

      delete activePullRequests[url];

      MergedPullRequestSuccess(claimant, url, devBounty, maintainerFee);
    }
  }

  function verifyMergedPullRequestFailedCallback(address claimant, string url) {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    MergedPullRequestFailed(claimant, url, collaterals[claimant]);
  }

  function verifyIssueSuccessCallback(address claimant, string url, string result) {
    issues[url].initialized = true;
    issueUrls.push(url);

    IssueSuccess(claimant, url, issues[url].bounty);
  }

  function verifyIssueFailedCallback(address claimant, string url) {
    delete issues[url];

    IssueFailed(claimant, url);
  }

  /* Parsing helpers */

  function checkPullRequest(address claimant, string url, string oraclizeResult) returns (bool) {
    // Expect Oraclize result to be of form:
    // ["<issueUrl>", "<body>"]
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var issueUrl = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice()).toString();
    var body = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();

    if (!issues[issueUrl].initialized) return false;
    if (!checkPullRequestAddr(claimant, body)) return false;

    return true;
  }

  function checkPullRequestAddr(address claimant, string body) returns (bool) {
    // Expect pull request body to be of form:
    // <ethAddr>\r\n<message>
    var strAddr = body.toSlice().split("\n".toSlice()).until("\r".toSlice()).toString();
    var pullRequestAddr = parseAddr(strAddr);

    if (pullRequestAddr == claimant) {
      return true;
    } else {
      return false;
    }
    return pullRequestAddr == claimant;
  }

  /* Withdrawl */

  function claimBounty() external {
    address payee = msg.sender;

    uint bounty = claimableBounties[payee];

    if (bounty == 0) throw;
    if (this.balance < bounty) throw;

    claimableBounties[payee] = 0;
    if (!payee.send(bounty)) {
      claimableBounties[payee] = bounty;
    }
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
