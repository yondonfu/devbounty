var accounts;
var account;

function updateEthNetworkStatus() {
  var addressField = document.getElementById("address");
  addressField.innerHTML = account;

  var walletBalanceField = document.getElementById("walletBalance");
  web3.eth.getBalance(account, function(err, balance) {
    walletBalanceField.innerHTML = web3.fromWei(balance, "ether") + " ETH";
  });

  var networkField = document.getElementById("network");
  web3.version.getNetwork(function(err, netId) {
    var networkName;

    if (netId == 1) {
      networkName = "Etherem Main Net";
    } else if (netId == 2) {
      networkName = "Morden Test Net";
    } else if (netId == 3) {
      networkName = "Ropsten Test Net";
    } else {
      networkName = "Unknown Network";
    }

    network.innerHTML = networkName;
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

    updateEthNetworkStatus();
  });
}
