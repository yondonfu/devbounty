pragma solidity ^0.4.6;

import "usingOraclize.sol";
import "strings.sol";

contract GithubOraclize is usingOraclize {
  using strings for *;

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

  function oraclizeQuery(string jsonHelper) returns(bytes32) {
    return oraclize_query('URL', jsonHelper, oraclizeGas);
  }

  /* Callbacks */

  function __callback(bytes32 queryId, string result) onlyOraclize {
    OraclizeCallback memory c = oraclizeCallbacks[queryId];

    if (c.queryType == OraclizeQueryType.VerifyMaintainer) {
      verifyMaintainerCallback(c.claimant, c.url, result);
    } else if (c.queryType == OraclizeQueryType.VerifyOpenedPullRequest) {
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

  function verifyMaintainerCallback(address claimant, string url, string result) {
    // Expect PROOF.md contents to be of the following form:
    // <addr>\n<addr>...
    var contents = result.toSlice();
    var delim = "\n".toSlice();
    var maintainers = new address[](contents.count(delim));

    bool verified = false;

    for (uint i = 0; i < maintainers.length; i++) {
      maintainers[i] = parseAddr(contents.split(delim).toString());

      if (maintainers[i] == claimant) verified = true;
    }

    if (!verified) {
      verifyMaintainerFailedCallback(claimant, url);
    } else {
      verifyMaintainerSuccessCallback(claimant, url, maintainers);
    }
  }

  function verifyOpenedPullRequestCallback(address claimant, string url, string result) {
    if (bytes(result).length == 0) {
      verifyOpenedPullRequestFailedCallback(claimant, url);
    } else {
      verifyOpenedPullRequestSuccessCallback(claimant, url, result);
    }
  }

  function verifyMergedPullRequestCallback(address claimant, string url, string result) {
    if (bytes(result).length == 0 || strCompare(result, "False") == 0) {
      verifyMergedPullRequestFailedCallback(claimant, url);
    } else {
      verifyMergedPullRequestSuccessCallback(claimant, url, result);
    }
  }

  function verifyIssueCallback(address claimant, string url, string result) {
    if (bytes(result).length == 0) {
      verifyIssueFailedCallback(claimant, url);
    } else {
      verifyIssueSuccessCallback(claimant, url, result);
    }
  }

  /* Post-verification operations. To be performed upon success or failure of verification */

  function verifyMaintainerSuccessCallback(address claimant, string url, address[] maintainers);

  function verifyMaintainerFailedCallback(address claimant, string url);

  function verifyOpenedPullRequestSuccessCallback(address claimant, string url, string result);

  function verifyOpenedPullRequestFailedCallback(address claimant, string url);

  function verifyMergedPullRequestSuccessCallback(address claimant, string url, string result);

  function verifyMergedPullRequestFailedCallback(address claimant, string url);

  function verifyIssueSuccessCallback(address claimant, string url, string result);

  function verifyIssueFailedCallback(address claimant, string url);
}
