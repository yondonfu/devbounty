const webpack = require('webpack');
const path = require('path');

const APP_DIR = path.resolve(__dirname, 'app');
const BUILD_DIR = path.resolve(__dirname, 'dist');
const CONTRACTS_DIR = path.resolve(__dirname, 'contracts');

const config = {
  entry: APP_DIR + '/javascripts/index.jsx',
  output: {
    path: BUILD_DIR,
    filename: 'bundle.js'
  },
  resolve: {
    alias: {
      contracts: CONTRACTS_DIR
    }
  },
  module: {
    loaders: [
      {
        test: /\.jsx?/,
        include: APP_DIR,
        loader: 'babel-loader'
      },
      {
        test: /\.sol/,
        include: CONTRACTS_DIR,
        loader: 'truffle-solidity-loader'
      }
    ]
  }
}

module.exports = config;
