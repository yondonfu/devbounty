pragma solidity ^0.4.6;

import "usingOraclize.sol";
import "strings.sol";

contract DevBounty is usingOraclize {
  using strings for *;

  struct OraclizeCallback {
    address sender;
    string url;
    OraclizeQueryType queryType;
  }

  enum OraclizeQueryType { VerifyMaintainer, NoQuery }

  // repository url => repository contract address
  mapping(string => address) public repositories;
  mapping(address => uint) public collaterals;
  mapping(bytes32 => OraclizeCallback) public oraclizeCallbacks;

  uint public minCollateral;
  uint public oraclizeGas;

  function DevBounty(uint _minCollateral, uint _oraclizeGas) {
    minCollateral = _minCollateral;
    oraclizeGas = _oraclizeGas;
  }

  function registerRepository(string url, uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) payable {
    if (msg.value < minCollateral) throw;

    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client provides constructed json helper - json(url)

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, OraclizeQueryType.VerifyMaintainer);
  }

  function oraclizeQuery(string jsonHelper) returns (bytes32 queryId) {
    return oraclize_query('URL', jsonHelper, oraclizeGas);
  }

  function __callback(bytes32 queryId, string result) {
    if (msg.sender != oraclize_cbAddress()) throw; // Non-oraclize message

    OraclizeCallback memory c = oraclizeCallbacks[oraclizeId];

    if (c.queryType == OraclizeQueryType.VerifyMaintainer) {
      verifyMaintainerCallback(c.sender, c.url, result);
    } else {
      // No query
      throw;
    }
  }

  function verifyMaintainerCallback(address sender, string url, string result) {
    if (!verifyMaintainer(result)) {
      collaterals[sender] -= calcPenalty(collaterals[sender]);
    } else {
      address repositoryAddr = new Repository(url, minCollateral, penaltyNum, penaltyDenom, oraclizeGas);
      repositories[url] = repositoryAddr;
    }
  }

  function verifyMaintainer(address sender, string result) {
    // Expect PROOF.md contents to be of the following form:
    // <ethAddr>\r\n<ethAddr>...
    var contents = result.toSlice();
    var delim = "\n".toSlice();
    var parts = new string[](contents.count(delim));

    for (uint i = 0; i < parts.length; i++) {
      parts[i] = contents.split(delim).toString();
    }

  }
}
