pragma solidity ^0.4.6;

import "strings.sol";
import "GithubOraclize.sol";
import "Collateralize.sol";
import "Repository.sol";

contract DevBounty is GithubOraclize, Collateralize {
  using strings for *;

  struct RepositoryMetadata {
    uint minCollateral;
    uint penaltyNum;
    uint penaltyDenom;
    uint maintainerFeeNum;
    uint maintainerFeeDenom;
    uint oraclizeGas;
    bool initialized;
  }

  string[] public repositoryUrls;

  // repository url => repository contract address
  mapping(string => address) repositories;
  mapping(string => RepositoryMetadata) repositoryMetadataSet;

  event MaintainerSuccess(address claimant, string url);
  event MaintainerFailed(address claimant, string url);

  function DevBounty(uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    oraclizeGas = _oraclizeGas;
  }

  function registerRepository(string jsonHelper, string url, uint minCollateral, uint penaltyNum, uint penaltyDenom, uint maintainerFeeNum, uint maintainerFeeDenom, uint oraclizeGas) requiresCollateral payable {
    collaterals[msg.sender] = msg.value;

    uint oraclizeFee = sendOraclizeQuery(msg.sender, jsonHelper, url, OraclizeQueryType.VerifyMaintainer); // Client provides constructed json helper - json(url)

    collaterals[msg.sender] -= oraclizeFee;

    repositoryMetadataSet[url] = RepositoryMetadata(minCollateral, penaltyNum, penaltyDenom, maintainerFeeNum, maintainerFeeDenom, oraclizeGas, false);
  }

  /* Callbacks */

  function __callback(bytes32 queryId, string result) onlyOraclize {
    OraclizeCallback memory c = oraclizeCallbacks[queryId];

    if (c.queryType == OraclizeQueryType.VerifyMaintainer) {
      verifyMaintainerCallback(c.claimant, c.url, result);
    } else {
      // Unknown query
      throw;
    }
  }

  function verifyMaintainerCallback(address claimant, string url, string result) internal {
    /* Expect PROOF.md contents to be of the following form: */
    /* <addr>\n<addr>... */
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

  function verifyMaintainerSuccessCallback(address claimant, string url, address[] maintainers) {
    repositoryMetadataSet[url].initialized = true;
    RepositoryMetadata memory meta = repositoryMetadataSet[url];

    address repositoryAddr = address(new Repository(url, maintainers, meta.minCollateral, meta.penaltyNum, meta.penaltyDenom, meta.maintainerFeeNum, meta.maintainerFeeDenom, meta.oraclizeGas));
    repositories[url] = repositoryAddr;
    repositoryUrls.push(url);

    MaintainerSuccess(claimant, url);
  }

  function verifyMaintainerFailedCallback(address claimant, string url) {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    delete repositoryMetadataSet[url];

    MaintainerFailed(claimant, url);
  }
}
