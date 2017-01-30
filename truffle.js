module.exports = {
  build: {
    "index.html": "index.html",
    "postBounty.html": "postBounty.html",
    "viewIssue.html": "viewIssue.html",
    "app.js": [
      "javascripts/app.js",
    ],
    "utils.js": [
      "javascripts/utils.js"
    ],
    "postBounty.js": [
      "javascripts/postBounty.js"
    ],
    "viewIssue.js": [
      "javascripts/viewIssue.js"
    ],
    "bootstrap.min.js": [
      "javascripts/bootstrap.min.js"
    ],
    "app.css": [
      "stylesheets/app.css"
    ],
    "bootstrap.min.css": [
      "stylesheets/bootstrap.min.css"
    ],
    "bootstrap-theme.min.css": [
      "stylesheets/bootstrap-theme.min.css"
    ],
    "images/": "images/"
  },
  rpc: {
    host: "localhost",
    port: 8545
  }
};
