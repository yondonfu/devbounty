console.log('Pull request script loaded!');

var discussionHeader = document.getElementById('partial-discussion-header');

var openBtn = document.createElement('button');
openBtn.innerHTML = 'Open DevBounty PR';
openBtn.className = 'open-btn'; 

openBtn.addEventListener('click', function() {
  var githubRoot = 'https://github.com/';
  var apiGithubRoot = 'https://api.github.com/repos/';
  var issueUrl = window.location.href;
  var issuePath = issueUrl.substring(githubRoot.length, issueUrl.lastIndexOf('/')) + 's';
  var issueNum = issueUrl.substring(issueUrl.lastIndexOf('/'));
  var apiUrl = 'json(' + apiGithubRoot + issuePath + issueNum + ').[url, issue_url]';

  alert(apiUrl);
});

// var mergeBtn = document.createElement('button');
// mergeBtn.innerHTML = 'Merge DevBounty PR';

discussionHeader.appendChild(openBtn);
// discussionHeader.appendChild(mergeBtn);
