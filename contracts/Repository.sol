pragma solidity ^0.4.4;

import "usingOraclize.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract Repository is usingOraclize {
  using strings for *;

  struct Issue {
    string url;
    uint bounty;
  }

  struct PullRequest {
    string url;
    Issue issue;
  }

  enum OraclizeQueryType { OpenPullRequest, MergePullRequest };

  OraclizeQueryType oraclizeQueryType;

  mapping(string => Issue) issues; // issue url => Issue

  mapping(address => uint) public collaterals; // developer address => posted collateral

  mapping(address => PullRequest) public activePullRequests; // developer address => PullRequest

  address activeDev;

  string public url;
  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;

  function Repository(string _url, uint _minCollateral, uint _penaltyNum, uint _penatlyDenom) {
    // ethereum-bridge
    OAR = OraclizeAddrResolverI(0x7c2b639ae051fdaeecc2f8692911627020304ae2);

    url = _url;
    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
  }

  function __callback(bytes32 myId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    if (oraclizeQueryType == OraclizeQueryType.OpenPullRequest) {
      if (bytes(result).length == 0) {
        // No open pull request
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);
      } else {
        createPullRequest(activeDev, result);
      }
    } else if (oraclizeQueryType == OraclizeQueryType.MergePullRequest) {
      if (result.strCompare("false") || bytes(activePullRequests[activeDev]).length == 0) {
        // Pull request not merged
        collaterals[activeDev] -= calcPenalty(collaterals[activeDev]);
      } else {
        // Pull request merged
        if (!activeDev.send(issues[activePullRequests.issueUrl].bounty)) throw;

        delete activePullRequests[activeDev];
      }
    } else {
      // Unknown oraclize query type
      throw;
    }

    activeDev = 0x0;
  }

  function createPullRequest(address addr, string oraclizeResult) {
    var resultSlice = oraclizeResult.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var url = resultSlice.split(",".toSlice()).toString();
    var issueUrl = resultSlice.toString();

    if (issues[issueUrl] == 0x0) throw; // Issue does not exist

    activePullRequests[addr] = PullRequest(url, issues[issueUrl]);
  }

  function fundIssue(string url, uint id) payable {
    issues[url].url = url;
    issues[url].id = id;
    issues[url].bounty += msg.value;
  }

  function getIssueByUrl(string url) public constant returns(string, uint, uint) {
    return (issues[url].url, issues[url].id, issues[url].bounty);
  }

  function registerDev() payable {
    if (msg.value < minCollateral) throw; // Insufficient collateral posted

    collaterals[msg.sender] = msg.value;
  }

  function mergePullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0x0) throw; // Not registered developer address
    if (activePullRequests[msg.sender] == 0x0) throw; // Developer has not opened a pull request

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.MergePullRequest;

    oraclize_query('URL', apiUrl); // Client has to provide the constructed api url i.e. json(url).merged
  }

  function openPullRequest(string apiUrl) {
    if (collaterals[msg.sender] == 0x0) throw; // Not registered developer address

    activeDev = msg.sender;
    oraclizeQueryType = OraclizeQueryType.OpenPullRequest;

    oraclize_query('URL', apiUrl); // Client has to provide the constructed api url - json(url).[url, issue_url]
  }

  function calcPenalty(uint amount) public constant returns(uint) {
    return (amount * penaltyNum) / penaltyDenom;
  }
}
