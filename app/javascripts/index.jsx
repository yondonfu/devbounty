import React from 'react';
import {render} from 'react-dom';
import App from './App.jsx';
import Web3 from 'web3';

import truffleConfig from '../../truffle.js';

let defaultWeb3Location = `http://${truffleConfig.rpc.host}:${truffleConfig.rpc.port}`;

window.addEventListener('load', function() {
  let web3Provided;

  if (typeof web3 !== 'undefined') {
    // Use wallet provider i.e. Metamask/Mist
    web3Provided = new Web3(web3.currentProvider);
  } else {
    // No web3 detected. Default to Truffle rpc host and port
    web3Provided = new Web3(new Web3.providers.HttpProvider(defaultWeb3Location));
  }

  render(<App web3={web3Provided}/>, document.getElementById('app'));
});
