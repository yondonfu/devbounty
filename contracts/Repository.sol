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
  mapping(address => PullRequest) activePullRequests; // developer address => PullRequest

  address activeDev;

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest, NoPullRequest }
  OraclizeQueryType oraclizeQueryType;

  event OpenCallbackSuccess(address addr, string result);
  event OpenCallbackFailed(bytes32 myId, string result);
  event MergeCallbackSuccess(uint bounty);
  event MergeCallbackFailed(bytes32 myId, string result);

  function Repository(string _url, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0xaf1005c8744cee939c1d837382d751918c26afff);

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

  function registerDev() payable {
    if (msg.value < minCollateral) throw; // Insufficient collateral

    collaterals[msg.sender] = msg.value;
  }

  function createPullRequest(address addr, string oraclizeResult) {
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var url = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice()).toString();
    var issueUrl = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();

    if (!issues[issueUrl].initialized) throw;

    activePullRequests[addr] = PullRequest(url, issues[issueUrl], true);
  }

  function getPullRequestByAddr(address addr) public constant returns(string, string) {
    return (activePullRequests[addr].url, activePullRequests[addr].issue.url);
  }

  function openPullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.OpenPullRequest;

    oraclizeQuery(apiUrl); // Client has to provide the constructed api url - json(url).[url, issue_url]
  }

  function mergePullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address
    if (!activePullRequests[msg.sender].initialized) throw; // Developer has not opened a pull request

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.MergePullRequest;

    oraclizeQuery(apiUrl); // Client has to provide the constructed api url i.e. json(url).merged
  }

  function oraclizeQuery(string apiUrl) {
    oraclize_query('URL', apiUrl, oraclizeGas);
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    if (oraclizeQueryType == OraclizeQueryType.OpenPullRequest) {
      if (bytes(result).length == 0) {
        // Invalid pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);

        OpenCallbackFailed(myId, result);
      } else {
        createPullRequest(activeDev, result);

        OpenCallbackSuccess(activeDev, result);
      }
    } else if (oraclizeQueryType == OraclizeQueryType.MergePullRequest) {
      if (strCompare(result, "False") == 0 || !activePullRequests[activeDev].initialized) {
        // Pull request not merged or no such open pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);

        MergeCallbackFailed(myId, result);
      } else {
        if (!activeDev.send(activePullRequests[activeDev].issue.bounty)) throw;

        MergeCallbackSuccess(activePullRequests[activeDev].issue.bounty);

        delete activePullRequests[activeDev];
      }
    } else {
      // No active pull request or unknown oraclize query type
      throw;
    }

    activeDev = 0x0;
  }

}
