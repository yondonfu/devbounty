var accounts;
var account;
var devBounty;
var issues;

function updateBounties() {
  var activeBounties = document.getElementById("activeBounties");
  var activeBountiesHTML = "";

  issues = []; // Clear

  devBounty.getIssueCount.call().then(function(count) {
    console.log("Issue Count: " + count);

    for (var i = 0; i < count; i++) {
      devBounty.issueUrls.call(i).then(function(url) {
        console.log(url);

        devBounty.getIssueByUrl.call(url).then(function(issue) {
          console.log(issue[0]);
          console.log(issue[1]);
          console.log(issue[2]);

          issues.push(issue);

          activeBountiesHTML = activeBountiesHTML + "<tr><td>" + issue[0] + "</td>" + "<td>" + web3.fromWei(issue[1], 'ether') +
          "</td><td><button class=\"btn btn-success view-issue-btn\">View Issue</button></td><td><a href=\"#\" class=\"btn btn-success fund-bounty-btn\">Fund Bounty</a></td></tr>";

          activeBounties.innerHTML = activeBountiesHTML;

        });
      });
    }
  });
}

function viewIssue(idx) {
  console.log(issues[idx]);
}

function setClickHandlers() {
  // $("body table tr").on("click", ".view-issue-btn", function(e) {
  //   console.log("yeah");
  // });
  $("body table").on("click", ".view-issue-btn", function(e) {
    var rowIdx = $(this).closest("td").parent()[0].sectionRowIndex;
    window.location = "viewIssue.html?url=" + issues[rowIdx][0];
  });
}

window.onload = function() {
  issues = [];
  web3.eth.getAccounts(function(err, accs) {
    if (err != null) {
      alert("There was an error fetching your accounts.");
      return;
    }

    if (accs.length == 0) {
      alert("Couldn't get any accounts! Make sure your Ethereum client is configured correctly.");
      return;
    }

    accounts = accs;
    account = accounts[0];

    getContractAddress(function(err, addr) {
      if (err != null) {
        console.log("Could not find network.");
      }

      devBounty = DevBounty.at(addr);

      console.log(devBounty);

      updateEthNetworkStatus();
      updateBounties();
      setClickHandlers();
    });

  });
}
