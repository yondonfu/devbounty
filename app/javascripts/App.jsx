import React from 'react';
import injectTapEventPlugin from 'react-tap-event-plugin';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';
import AppBar from 'material-ui/AppBar';
import Home from './Home.jsx';

import DevBounty from 'contracts/DevBounty.sol';

class App extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      networkName: '',
      account: '',
      devBounty: {
        minCollateral: 0,
        penalty: 0
      }
    };

    DevBounty.setProvider(this.props.web3.currentProvider);

    this.getEthNetworkStatus = this.getEthNetworkStatus.bind(this);
    this.getAccount = this.getAccount.bind(this);
  }

  getEthNetworkStatus() {
    this.props.web3.version.getNetwork((err, netId) => {
      let networkName;

      if (netId == 1) {
        networkName = 'Ethereum Main Net';
      } else if (netId == 2) {
        networkName = 'Morden Test Net';
      } else if (netId == 3) {
        networkName = 'Ropsten Test Net';
      } else {
        networkName = 'Unknown Network';
      }

      this.setState({networkName: networkName});
    });
  }

  getAccount() {
    this.props.web3.eth.getAccounts((err, accs) => {
      if (err != null || accs.length == 0) {
        alert("There was an error fetching your account. Make sure your Ethereum client is configured properly");
        return;
      }

      this.setState({account: accs[0]});
    });
  }

  getDevBountyParams() {
    const devBounty = DevBounty.deployed();

    const minCollateral = devBounty.minCollateral.call();
    const penaltyNum = devBounty.penaltyNum.call();
    const penaltyDenom = devBounty.penaltyDenom.call();

    Promise.all([minCollateral, penaltyNum, penaltyDenom]).then((values) => {
      this.setState({
        devBounty: {
          minCollateral: values[0].toNumber(),
          penalty: values[1].toNumber() / values[2].toNumber()
        }
      });
    });
  }

  componentDidMount() {
    this.getEthNetworkStatus();
    this.getAccount();
    this.getDevBountyParams();
  }

  render() {
    return (
      <div>
        <MuiThemeProvider>
          <AppBar
            title="DevBounty"
            iconClassNameRight="muidocs-icon-navigation-expand-more"
            />
        </MuiThemeProvider>
        <Home/>
      </div>
    );
  }
}

injectTapEventPlugin();

export default App;
