import React from 'react';
import MuiThemeProvider from 'material-ui/styles/MuiThemeProvider';
import RaisedButton from 'material-ui/RaisedButton';

class Home extends React.Component {
  onPostBounty() {
    console.log('Clicked');
  }

  render() {
    return (
      <div>
        <h1>DevBounty</h1>
        <p>Rewards for Open Source Contributions</p>
        <MuiThemeProvider>
          <RaisedButton onClick={this.onPostBounty} label="Post Bounty"/>
        </MuiThemeProvider>
      </div>
    );
  }
}

export default Home;
