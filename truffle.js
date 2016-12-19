module.exports = {
  build: {
    "index.html": "index.html",
    "app.js": [
      "javascripts/app.js",
      "background.js",
      "issue.js"
    ],
    "app.css": [
      "stylesheets/app.css"
    ],
    "images/": "images/"
  },
  rpc: {
    host: "localhost",
    port: 8545
  }
};
