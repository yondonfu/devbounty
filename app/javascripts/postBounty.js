var accounts;
var account;
var devBounty;

function postBounty() {
  var issueUrl = document.getElementById("issue-url").value;
  var amount = document.getElementById("amount").value;

  amount = web3.toWei(amount, "ether");

  var jsonHelper = "json(" + issueUrl + ").url";
  console.log(issueUrl);
  console.log(amount);
  console.log(jsonHelper);

  devBounty.fundIssue(issueUrl, jsonHelper, {from: account, value: amount, gas: 1000000}).then(function(txId) {
    console.log(txId);
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
    });
  });

}
