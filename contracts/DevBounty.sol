pragma solidity ^0.4.6;

import "usingOraclize.sol";
import "strings.sol";

contract DevBounty is usingOraclize {
  using strings for *;

  struct Issue {
    string url;
    uint bounty;
    bool initialized;
  }

  struct PullRequest {
    string url;
    Issue issue;
    bool initialized;
  }

  struct OraclizeCallback {
    address dev;
    string prUrl;
    OraclizeQueryType queryType;
  }

  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;
  uint public oraclizeGas;

  mapping(string => Issue) issues; // issue url => Issue
  mapping(address => uint) public collaterals; // developer address => posted collateral
  mapping(address => uint) public claimableBounties; // developer address => claimable bounty amount
  mapping(address => PullRequest) activePullRequests; // developer address => PullRequest

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest, NoPullRequest }
  OraclizeQueryType oraclizeQueryType;

  mapping(bytes32 => OraclizeCallback) public oraclizeCallbacks;

  event OpenCallbackSuccess(address dev, string prUrl);
  event OpenCallbackFailed(address dev, uint updatedCollateral);
  event MergeCallbackSuccess(address dev, uint updatedClaimableBounty);
  event MergeCallbackFailed(address dev, uint updatedCollateral);

  function DevBounty(uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0xd1e765da435b5864501a0ba747cdb6f1b77b1d74);

    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    oraclizeGas = _oraclizeGas;
  }

  function calcPenalty(uint amount) public constant returns(uint) {
    return (amount * penaltyNum) / penaltyDenom;
  }

  function fundIssue(string url) payable {
    if (!issues[url].initialized) {
      issues[url] = Issue(url, msg.value, true);
    } else {
      issues[url].bounty += msg.value;
    }
  }

  function getIssueByUrl(string url) public constant returns(string, uint, bool) {
    return (issues[url].url, issues[url].bounty, issues[url].initialized);
  }

  function openPullRequest(string apiUrl, string prUrl) payable {
    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(apiUrl); // Client has to provide the constructed api url - json(url).[issue_url, body]
    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, prUrl, OraclizeQueryType.OpenPullRequest);

    uint updatedBalance = this.balance;
    uint balanceDiff = initialBalance - updatedBalance;
    collaterals[msg.sender] -= balanceDiff;
  }

  function mergePullRequest(string apiUrl, string prUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address
    if (!activePullRequests[msg.sender].initialized) throw; // Developer has not opened a pull request

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(apiUrl); // Client has to provide the constructed api url i.e. json(url).merged
    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, prUrl, OraclizeQueryType.MergePullRequest);

    uint updatedBalance = this.balance;
    uint balanceDiff = initialBalance - updatedBalance;
    collaterals[msg.sender] -= balanceDiff;
  }

  function oraclizeQuery(string apiUrl) returns(bytes32) {
    return oraclize_query('URL', apiUrl, oraclizeGas);
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    OraclizeCallback memory c = oraclizeCallbacks[myId];

    if (c.queryType == OraclizeQueryType.OpenPullRequest) {
      openCallback(c.dev, c.prUrl, result);
    } else if (c.queryType == OraclizeQueryType.MergePullRequest) {
      mergeCallback(c.dev, result);
    } else {
      // No active pull request or unknown oraclize query type
      throw;
    }
  }

  function openCallback(address addr, string prUrl, string result) {
    if (!createPullRequest(addr, prUrl, result)) {
      // Invalid pull request
      collaterals[addr] -= calcPenalty(collaterals[addr]);

      OpenCallbackFailed(addr, collaterals[addr]);
    } else {
      OpenCallbackSuccess(addr, prUrl);
    }
  }

  function mergeCallback(address addr, string result) {
    if (bytes(result).length == 0 || strCompare(result, "False") == 0 || !activePullRequests[addr].initialized) {
      // Pull request not merged or no such open pull request
      collaterals[addr] -= calcPenalty(collaterals[addr]);

      MergeCallbackFailed(addr, collaterals[addr]);
    } else {
      claimableBounties[addr] += activePullRequests[addr].issue.bounty;

      MergeCallbackSuccess(addr, claimableBounties[addr]);

      delete activePullRequests[addr];
    }
  }

  function createPullRequest(address addr, string prUrl, string oraclizeResult) returns(bool) {
    if (bytes(oraclizeResult).length == 0) return false;

    // Expect Oraclize result to be of form:
    // ["<issueUrl>", "<body>"]
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var issueUrl = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice()).toString();
    var body = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();

    if (!issues[issueUrl].initialized) return false;
    if (!checkPullRequestAddr(addr, body)) return false;

    activePullRequests[addr] = PullRequest(prUrl, issues[issueUrl], true);

    return true;
  }

  function checkPullRequestAddr(address addr, string prBody) returns(bool) {
    // Expect pull request body to be of form:
    // <ethAddr>\r\n<message>
    var strAddr = prBody.toSlice().split("\n".toSlice()).until("\r".toSlice()).toString();
    var pullRequestAddr = parseAddr(strAddr);

    if (pullRequestAddr == addr) {
      return true;
    } else {
      return false;
    }
  }

  function getPullRequestByAddr(address addr) public constant returns(string, string) {
    return (activePullRequests[addr].url, activePullRequests[addr].issue.url);
  }

  function claimPayment() external {
    uint bounty = claimableBounties[msg.sender];
    uint collateral = collaterals[msg.sender];
    uint payment = bounty + collateral;

    if (payment == 0) throw;
    if (this.balance < payment) throw;

    claimableBounties[msg.sender] = 0;
    collaterals[msg.sender] = 0;
    if (!msg.sender.send(payment)) {
      claimableBounties[msg.sender] = bounty;
      collaterals[msg.sender] = collateral;
    }
  }

}
