var apiUrl;

function httpGetAsync(url, callback) {
  var xmlHttp = new XMLHttpRequest();
  xmlHttp.onreadystatechange = function() {
    if (xmlHttp.readyState == 4 && xmlHttp.status == 200) {
      var res = JSON.parse(xmlHttp.responseText);
      callback(res);
    }
  };

  xmlHttp.open("GET", url, true); // async
  xmlHttp.send(null);
}

function getComments() {
  var url = apiUrl + "/comments";

  httpGetAsync(url, function(res) {
    if (res) {
      console.log(res);
    }
  });
}

function getDetails() {
  httpGetAsync(apiUrl, function(res) {
    if (res) {
      var title = document.getElementById("title");
      var htmlUrl = document.getElementById("html-url");
      var number = document.getElementById("number");
      var user = document.getElementById("user");
      var body = document.getElementById("body");

      title.innerHTML = res.title;
      htmlUrl.innerHTML = res.html_url;
      number.innerHTML = res.number;
      user.innerHTML = res.user.login;
      body.innerHTML = res.body;
    }
  });
}

function parseQueryUrl() {
  apiUrl = location.search.split("url=")[1];
}

window.onload = function() {
  parseQueryUrl();
  getDetails();
  getComments();
}
