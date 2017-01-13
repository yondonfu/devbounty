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

function getContractAddress(callback) {
  web3.version.getNetwork(function(err, netId) {
    var err;
    var addr;

    if (netId == 1) {
      err = "DevBounty is not deployed on main net yet.";
    } else if (netId == 2) {
      err = "DevBounty is not deployed on Morden test net yet.";
      addr = "";
    } else if (netId == 3) {
      err = "DevBounty is not deployed on Ropsten test net yet.";
    } else {
      // Local dev with testrpc
      addr = "0x58d27d93f25ad2bb0dcc6a3cc6e14d1989a305be";
    }

    callback(err, addr);
  });
}
