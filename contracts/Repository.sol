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

  mapping(string => Issue) issues; // issue url => Issue
  mapping(address => uint) public collaterals; // developer address => posted collateral
  mapping(address => PullRequest) activePullRequests; // developer address => PullRequest

  address activeDev;

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest, NoPullRequest }
  OraclizeQueryType oraclizeQueryType;

  function Repository(string _url, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0xa0f0f1b1ca09a763f9000c46c3b0baedd099fbdb);

    url = _url;
    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
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

  function getIssueByUrl(string url) public constant returns(string, uint) {
    return (issues[url].url, issues[url].bounty);
  }

  function registerDev() payable {
    if (msg.value < minCollateral) throw; // Insufficient collateral

    collaterals[msg.sender] = msg.value;
  }

  function createPullRequest(address addr, string oraclizeResult) {
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var url = resultSlice.split(",".toSlice()).toString();
    var issueUrl = resultSlice.toString();

    if (!issues[issueUrl].initialized) throw; // Issue does not exist

    activePullRequests[addr] = PullRequest(url, issues[issueUrl], true);
  }

  function getPullRequestByAddr(address addr) public constant returns(string, string) {
    return (activePullRequests[addr].url, activePullRequests[addr].issue.url);
  }

  function openPullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.OpenPullRequest;

    oraclize_query('URL', apiUrl); // Client has to provide the constructed api url - json(url).[url, issue_url]
  }

  function mergePullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0) throw; // Not registered developer address
    if (!activePullRequests[msg.sender].initialized) throw; // Developer has not opened a pull request

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.MergePullRequest;

    oraclize_query('URL', apiUrl); // Client has to provide the constructed api url i.e. json(url).merged
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    if (oraclizeQueryType == OraclizeQueryType.OpenPullRequest) {
      if (bytes(result).length == 0) {
        // Invalid pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);
      } else {
        createPullRequest(activeDev, result);
      }
    } else if (oraclizeQueryType == OraclizeQueryType.MergePullRequest) {
      if (strCompare(result, "false") == 0 || !activePullRequests[activeDev].initialized) {
        // Pull request not merged or no such open pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);
      } else {
        if (!activeDev.send(activePullRequests[activeDev].issue.bounty)) throw;

        delete activePullRequests[activeDev];
      }
    } else {
      // No active pull request or unknown oraclize query type
      throw;
    }

    activeDev = 0x0;
  }

}
