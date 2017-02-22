pragma solidity ^0.4.6;

import "usingOraclize.sol";

contract GithubOraclize is usingOraclize {
  struct OraclizeCallback {
    address claimant;
    string url;
    OraclizeQueryType queryType;
  }

  enum OraclizeQueryType { VerifyMaintainer, VerifyOpenedPullRequest, VerifyMergedPullRequest, VerifyIssue }
  OraclizeQueryType oraclizeQueryType;

  uint public oraclizeGas;

  // oraclize query id => OraclizeCallback
  mapping(bytes32 => OraclizeCallback) public oraclizeCallbacks;

  modifier onlyOraclize() {
    if (msg.sender != oraclize_cbAddress()) throw;
    _;
  }

  function oraclizeQuery(string jsonHelper) internal returns (bytes32) {
    return oraclize_query('URL', jsonHelper, oraclizeGas);
  }

  function sendOraclizeQuery(address claimant, string jsonHelper, string url, OraclizeQueryType queryType) internal returns (uint) {
    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper);

    uint updatedBalance = this.balance;

    oraclizeCallbacks[queryId] = OraclizeCallback(claimant, url, queryType);

    return initialBalance - updatedBalance;
  }

  /* Callbacks */

  function __callback(bytes32 queryId, string result);
}
