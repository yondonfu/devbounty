pragma solidity ^0.4.6;

import "usingOraclize.sol";

contract GithubOraclize is usingOraclize {
  struct OraclizeCallback {
    address claimant;
    string repoUrl;
    string apiUrl;
    OraclizeQueryType queryType;
  }

  enum OraclizeQueryType { VerifyMaintainer, VerifyOpenedPullRequest, VerifyMergedPullRequest, VerifyIssue }
  OraclizeQueryType oraclizeQueryType;

  uint public oraclizeGas;

  mapping(bytes32 => OraclizeCallback) public oraclizeCallbacks;

  modifier onlyOraclize() {
    if (msg.sender != oraclize_cbAddress()) throw;
    _;
  }

  function oraclizeQuery(string jsonHelper) internal returns (bytes32) {
    return oraclize_query('URL', jsonHelper, oraclizeGas);
  }

  function sendOraclizeQuery(address claimant, string jsonHelper, string repoUrl, string apiUrl, OraclizeQueryType queryType) internal returns (uint) {
    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper);

    uint updatedBalance = this.balance;

    oraclizeCallbacks[queryId] = OraclizeCallback(claimant, repoUrl, apiUrl, queryType);

    return initialBalance - updatedBalance;
  }
}
