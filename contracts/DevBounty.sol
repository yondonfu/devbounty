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
    string url;
    uint value;
    OraclizeQueryType queryType;
  }

  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;
  uint public oraclizeGas;

  string[] public issueUrls;
  mapping(string => Issue) issues; // issue url => Issue
  mapping(address => PullRequest) activePullRequests; // developer address => PullRequest
  mapping(address => uint) public collaterals; // developer address => posted collateral
  mapping(address => uint) public claimableBounties; // developer address => claimable bounty amount

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest, FundIssue, NoQuery }
  OraclizeQueryType oraclizeQueryType;

  mapping(bytes32 => OraclizeCallback) public oraclizeCallbacks;

  event OpenCallbackSuccess(address dev, string url);
  event OpenCallbackFailed(address dev, string url, uint updatedCollateral);
  event MergeCallbackSuccess(address dev, string url, uint updatedClaimableBounty);
  event MergeCallbackFailed(address dev, string url, uint updatedCollateral);
  event FundIssueCallbackSuccess(address dev, string url, uint updatedBounty);
  event FundIssueCallbackFailed(address dev, string url);

  function DevBounty(uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0x5f7f6557f56bdaa7b9d7ffa52c8bae05f0b587fc);

    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    oraclizeGas = _oraclizeGas;
  }

  function calcPenalty(uint amount) public constant returns(uint) {
    return (amount * penaltyNum) / penaltyDenom;
  }

  function fundIssue(string url, string jsonHelper) payable {
    if (!issues[url].initialized) {
      uint initialBalance = this.balance;

      // Need to verify that the issue exists
      bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed json helper - json(url).url

      uint updatedBalance = this.balance;
      uint oraclizeFee = initialBalance - updatedBalance;

      oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, msg.value - oraclizeFee, OraclizeQueryType.FundIssue);
    } else {
      // Already know the issue exists so we do not need an oraclize query
      issues[url].bounty += msg.value;
    }
  }

  function getIssueCount() public constant returns (uint) {
    return issueUrls.length;
  }

  function getIssueByUrl(string url) public constant returns(string, uint, bool) {
    return (issues[url].url, issues[url].bounty, issues[url].initialized);
  }

  function openPullRequest(string url, string jsonHelper) payable {
    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed jsonHelper - json(url).[issue_url, body]

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, 0, OraclizeQueryType.OpenPullRequest);
  }

  function mergePullRequest(string url, string jsonHelper) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address
    if (!activePullRequests[msg.sender].initialized) throw; // Developer has not opened a pull request

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client has to provide the constructed jsonHelper i.e. json(url).merged

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, 0, OraclizeQueryType.MergePullRequest);
 }

  function oraclizeQuery(string jsonHelper) returns(bytes32) {
    return oraclize_query('URL', jsonHelper, oraclizeGas);
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    OraclizeCallback memory c = oraclizeCallbacks[myId];

    if (c.queryType == OraclizeQueryType.OpenPullRequest) {
      openCallback(c.dev, c.url, result);
    } else if (c.queryType == OraclizeQueryType.MergePullRequest) {
      mergeCallback(c.dev, c.url, result);
    } else if (c.queryType == OraclizeQueryType.FundIssue) {
      fundIssueCallback(c.dev, c.url, c.value, result);
    } else {
      // No query
      throw;
    }
  }

  function openCallback(address addr, string url, string result) {
    if (!createPullRequest(addr, url, result)) {
      // Invalid pull request
      collaterals[addr] -= calcPenalty(collaterals[addr]);

      OpenCallbackFailed(addr, url, collaterals[addr]);
    } else {
      OpenCallbackSuccess(addr, url);
    }
  }

  function mergeCallback(address addr, string url, string result) {
    if (bytes(result).length == 0 || strCompare(result, "False") == 0 || !activePullRequests[addr].initialized) {
      // Pull request not merged or no such open pull request
      collaterals[addr] -= calcPenalty(collaterals[addr]);

      MergeCallbackFailed(addr, url, collaterals[addr]);
    } else {
      claimableBounties[addr] += activePullRequests[addr].issue.bounty;

      MergeCallbackSuccess(addr, url, claimableBounties[addr]);

      delete activePullRequests[addr];
    }
  }

  function fundIssueCallback(address addr, string url, uint value, string result) {
    if (bytes(result).length == 0) {
      // Issue does not exist
      FundIssueCallbackFailed(addr, url);
    } else {
      issues[url] = Issue(url, value, true);
      issueUrls.push(url);

      FundIssueCallbackSuccess(addr, url, value);
    }
  }

  function createPullRequest(address addr, string url, string oraclizeResult) returns(bool) {
    if (bytes(oraclizeResult).length == 0) return false;

    // Expect Oraclize result to be of form:
    // ["<issueUrl>", "<body>"]
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var issueUrl = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice()).toString();
    var body = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();

    if (!issues[issueUrl].initialized) return false;
    if (!checkPullRequestAddr(addr, body)) return false;

    activePullRequests[addr] = PullRequest(url, issues[issueUrl], true);

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
