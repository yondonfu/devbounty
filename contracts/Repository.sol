pragma solidity ^0.4.6;

library Repository {
  struct Repo {
    string url;
    uint minCollateral;
    uint penaltyNum;
    uint penaltyDenom;
    uint maintainerFeeNum;
    uint maintainerFeeDenom;
    bool initialized;

    string[] issueUrls;

    mapping(address => bool) maintainers;
    mapping(address => uint) claimableBounties;
    mapping(string => Issue) issues;
    mapping(string => PullRequest) pullRequests;
  }

  struct Issue {
    string url;
    uint bounty;
    bool initialized;
  }

  struct PullRequest {
    string url;
    address owner;
    Issue issue;
    bool initialized;
  }

  function createIssue(Repo storage self, string url, uint bounty) {
    self.issues[url] = Issue(url, bounty, false);
  }

  function initIssue(Repo storage self, string url) {
    self.issues[url].initialized = true;
    self.issueUrls.push(url);
  }

  function updateIssueBounty(Repo storage self, string url, uint bounty) {
    self.issues[url].bounty += bounty;
  }

  function deleteIssue(Repo storage self, string url) {
    delete self.issues[url];
    // TODO: update issueUrls somehow
  }

  function createPullRequest(Repo storage self, string url, address owner, string issueUrl) {
    self.pullRequests[url] = PullRequest(url, owner, self.issues[issueUrl], false);
  }

  function initPullRequest(Repo storage self, string url) {
    self.pullRequests[url].initialized = true;
  }

  function deletePullRequest(Repo storage self, string url) {
    delete self.pullRequests[url];
  }

  function computeBounties(Repo storage self, address addr, string url) {
    uint bounty = self.pullRequests[url].issue.bounty;
    uint maintainerFee = (bounty * self.maintainerFeeNum) / self.maintainerFeeDenom;
    uint devBounty = bounty - maintainerFee;

    self.claimableBounties[addr] += maintainerFee;
    self.claimableBounties[self.pullRequests[url].owner] += devBounty;
  }

  function issueExists(Repo storage self, string url) returns (bool) {
    return self.issues[url].initialized;
  }

  function getIssueCount(Repo storage self) returns (uint) {
    return self.issueUrls.length;
  }

  function getIssueByUrl(Repo storage self, string url) returns (uint, bool) {
    return (self.issues[url].bounty, self.issues[url].initialized);
  }

  function pullRequestExists(Repo storage self, string url) returns (bool) {
    return self.pullRequests[url].initialized;
  }

  function getPullRequestByUrl(Repo storage self, string url) returns (address, string, bool) {
    return (self.pullRequests[url].owner, self.pullRequests[url].issue.url, self.pullRequests[url].initialized);
  }

  function hasMaintainer(Repo storage self, address addr) returns (bool) {
    return self.maintainers[addr];
  }

  function addMaintainer(Repo storage self, address addr) {
    self.maintainers[addr] = true;
  }

  function setMaintainerFee(Repo storage self, uint _maintainerFeeNum, uint _maintainerFeeDenom) {
    self.maintainerFeeNum = _maintainerFeeNum;
    self.maintainerFeeDenom = _maintainerFeeDenom;
  }

}
