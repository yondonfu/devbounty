console.log('Issue script loaded!');

var headerActions = document.getElementsByClassName('gh-header-actions')[0];

var postBountyBtn = document.createElement('button');
postBountyBtn.innerHTML = 'Post Bounty';
postBountyBtn.className = 'post-bounty-btn';

postBountyBtn.addEventListener('click', function() {
  var githubRoot = 'https://github.com/';
  var apiGithubRoot = 'https://api.github.com/repos/';
  var issueUrl = window.location.href;
  var issuePath = issueUrl.substring(githubRoot.length);
  var apiUrl = apiGithubRoot + issuePath;

  if (web3 == undefined) {
    console.log("metamask is installed");
  } else {
    console.log("metamask installed");
  }

  alert(apiUrl);
});

// var fundBountyBtn = document.createElement('button');
// fundBountyBtn.innerHTML = 'Fund Bounty';
// var claimBountyBtn = document.createElement('button');
// claimBountyBtn.innerHTML = 'Claim Bounty';

headerActions.appendChild(postBountyBtn);
// headerActions.appendChild(fundBountyBtn);
// headerActions.appendChild(claimBountyBtn);

var headerMeta = document.getElementsByClassName('TableObject-item TableObject-item--primary')[0];

var bountyAmount = document.createElement('span');
bountyAmount.innerHTML = '· Bounty: 50 ETH';

headerMeta.appendChild(bountyAmount);
