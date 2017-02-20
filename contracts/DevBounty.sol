pragma solidity ^0.4.6;

import "GithubOraclize.sol";
import "Collateralize.sol";
import "Repository.sol";

contract DevBounty is GithubOraclize, Collateralize {
  struct RepositoryMetadata {
    uint minCollateral;
    uint penaltyNum;
    uint penaltyDenom;
    uint oraclizeGas;
    bool initialized;
  }

  string[] public repositoryUrls;

  // repository url => repository contract address
  mapping(string => address) public repositories;
  mapping(string => RepositoryMetadata) repositoryMetadataSet;

  event MaintainerSuccess(address claimant, string url);
  event MaintainerFailed(address claimant, string url);

  function DevBounty(uint _minCollateral, uint _penaltyNum, uint _penaltyDenom, uint _oraclizeGas) {
    minCollateral = _minCollateral;
    penaltyNum = _penaltyNum;
    penaltyDenom = _penaltyDenom;
    oraclizeGas = _oraclizeGas;
  }

  function registerRepository(string jsonHelper, string url, uint minCollateral, uint penaltyNum, uint penaltyDenom, uint oraclizeGas) requiresCollateral payable {
    collaterals[msg.sender] = msg.value;

    uint initialBalance = this.balance;

    bytes32 queryId = oraclizeQuery(jsonHelper); // Client provides constructed json helper - json(url)

    uint updatedBalance = this.balance;
    uint oraclizeFee = initialBalance - updatedBalance;
    collaterals[msg.sender] -= oraclizeFee;

    repositoryMetadataSet[url] = RepositoryMetadata(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, false);

    oraclizeCallbacks[queryId] = OraclizeCallback(msg.sender, url, OraclizeQueryType.VerifyMaintainer);
  }

  /* Post-verification operations. */

  function verifyMaintainerSuccessCallback(address claimant, string url, address[] maintainers) {
    repositoryMetadataSet[url].initialized = true;
    RepositoryMetadata memory meta = repositoryMetadataSet[url];

    address repositoryAddr = new Repository(url, maintainers, meta.minCollateral, meta.penaltyNum, meta.penaltyDenom, meta.oraclizeGas);
    repositories[url] = repositoryAddr;
    repositoryUrls.push(url);

    MaintainerSuccess(claimant, url);
  }

  function verifyMaintainerFailedCallback(address claimant, string url) {
    collaterals[claimant] -= calcPenalty(collaterals[claimant]);

    delete repositoryMetadataSet[url];

    MaintainerFailed(claimant, url);
  }

  function verifyOpenedPullRequestSuccessCallback(address claimant, string url, string result) {
    // Not needed for this contract
  }

  function verifyOpenedPullRequestFailedCallback(address claimant, string url) {
    // Not needed for this contract
  }

  function verifyMergedPullRequestSuccessCallback(address claimant, string url, string result) {
    // Not needed for this contract
  }

  function verifyMergedPullRequestFailedCallback(address claimant, string url) {
    // Not needed for this contract
  }

  function verifyIssueSuccessCallback(address claimant, string url, uint amount) {
    // Not needed for this contract
  }

  function verifyIssueFailedCallback(address claimant, string url) {
    // Not needed for this contract
  }

}
