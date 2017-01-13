var accounts;
var account;
var devBounty;

function updateBounties() {
  var activeBounties = document.getElementById("activeBounties");
  var activeBountiesHTML = "";

  devBounty.getIssueCount.call().then(function(count) {
    console.log("Issue Count: " + count);

    for (var i = 0; i < count; i++) {
      devBounty.issueUrls.call(i).then(function(url) {
        console.log(url);

        devBounty.getIssueByUrl.call(url).then(function(issue) {
          console.log(issue[0]);
          console.log(issue[1]);
          console.log(issue[2]);

          activeBountiesHTML = activeBountiesHTML + "<tr><td>" + issue[0] + "</td>" + "<td>" + web3.fromWei(issue[1], 'ether') +
          "</td><td><a href=\"#\" class=\"btn btn-success\">View Issue</a></td><td><a href=\"#\" class=\"btn btn-success\">Fund Bounty</a></td></tr>";

          activeBounties.innerHTML = activeBountiesHTML;
        });
      });
    }
  });
}

window.onload = function() {
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
    });

  });
}
