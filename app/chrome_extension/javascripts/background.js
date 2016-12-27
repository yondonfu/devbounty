chrome.webNavigation.onHistoryStateUpdated.addListener(function(details) {
  var issuesRe = /:\/\/github.com\/[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+\/issues\/[0-9]+/;
  var pullRequestsRe = /:\/\/github.com\/[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+\/pull\/[0-9]+/;

  if (details.url.match(issuesRe)) {
    chrome.tabs.executeScript(null, {file: 'issue.js'});
  }

  if (details.url.match(pullRequestsRe)) {
    chrome.tabs.executeScript(null, {file: 'pullrequest.js'});
  }
});
