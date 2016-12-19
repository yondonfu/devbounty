pragma solidity ^0.4.6;

import "usingOraclize.sol";
import "strings.sol";

contract Repository is usingOraclize {
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

  string public url;
  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;
  uint public oraclizeGas;

  mapping(string => Issue) issues; // issue url => Issue
  mapping(address => uint) public collaterals; // developer address => posted collateral
  mapping(address => uint) public claimableBounties; // developer address => claimable bounty amount
  mapping(address => PullRequest) activePullRequests; // developer address => PullRequest

  address activeDev;
  string activePullRequestUrl;

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest, NoPullRequest }
  OraclizeQueryType oraclizeQueryType;

  event OpenCallbackSuccess(bytes32 myId, string result);
  event OpenCallbackFailed(bytes32 myId, string result);
  event MergeCallbackSuccess(bytes32 myId, string result);
  event MergeCallbackFailed(bytes32 myId, string result);

  function Repository(string _url, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0x7b5f554ac4274b59f35ad6b832829453cde5ecee);

    url = _url;
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

  function createPullRequest(address addr, string prUrl, string oraclizeResult) returns(bool) {
    if (bytes(oraclizeResult).length == 0) return false;

    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var issueUrl = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice()).toString();
    var body = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();

    if (!issues[issueUrl].initialized) return false;
    if (!checkPullRequestAddr(addr, body)) return false;

    activePullRequests[addr] = PullRequest(prUrl, issues[issueUrl], true);

    return true;
  }

  function checkPullRequestAddr(address addr, string pullRequestBody) returns(bool) {
    var strAddr = pullRequestBody.toSlice().split("\n".toSlice()).until("\r".toSlice()).toString();
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

  function openPullRequest(string apiUrl, string prUrl) payable {
    collaterals[msg.sender] = msg.value;

    activeDev = msg.sender;
    activePullRequestUrl = prUrl;
    oraclizeQueryType = OraclizeQueryType.OpenPullRequest;

    uint initialBalance = this.balance;

    oraclizeQuery(apiUrl); // Client has to provide the constructed api url - json(url).[issue_url, body]

    uint updatedBalance = this.balance;
    uint balanceDiff = initialBalance - updatedBalance;
    collaterals[msg.sender] -= balanceDiff;
  }

  function mergePullRequest(string apiUrl, string prUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address
    if (!activePullRequests[msg.sender].initialized) throw; // Developer has not opened a pull request

    activeDev = msg.sender;
    activePullRequestUrl = prUrl;
    oraclizeQueryType = OraclizeQueryType.MergePullRequest;

    uint initialBalance = this.balance;

    oraclizeQuery(apiUrl); // Client has to provide the constructed api url i.e. json(url).merged

    uint updatedBalance = this.balance;
    uint balanceDiff = initialBalance - updatedBalance;
    collaterals[msg.sender] -= balanceDiff;
  }

  function oraclizeQuery(string apiUrl) {
    oraclize_query('URL', apiUrl, oraclizeGas);
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    if (oraclizeQueryType == OraclizeQueryType.OpenPullRequest) {
      if (!createPullRequest(activeDev, activePullRequestUrl, result)) {
        // Invalid pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);

        OpenCallbackFailed(myId, result);
      } else {
        OpenCallbackSuccess(myId, result);
      }
    } else if (oraclizeQueryType == OraclizeQueryType.MergePullRequest) {
      if (bytes(result).length == 0 || strCompare(result, "False") == 0 || !activePullRequests[activeDev].initialized) {
        // Pull request not merged or no such open pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);

        MergeCallbackFailed(myId, result);
      } else {
        claimableBounties[activeDev] += activePullRequests[activeDev].issue.bounty;

        MergeCallbackSuccess(myId, result);

        delete activePullRequests[activeDev];
      }
    } else {
      // No active pull request or unknown oraclize query type
      throw;
    }

    oraclizeQueryType = OraclizeQueryType.NoPullRequest;
    activeDev = 0x0;
    activePullRequestUrl = '';
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
