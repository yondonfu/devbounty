pragma solidity ^0.4.6;

import "strings.sol";

library GithubOraclizeParser {
  using strings for *;

  function isValid(string self) returns (bool) {
    return bytes(self).length == 0;
  }

  function isFalse(string self) returns (bool) {
    var result = self.toSlice().compare("False".toSlice());

    if (result == 0) {
      return true;
    } else {
      return false;
    }
  }

  // Borrowed from https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.4.sol
  function toAddr(string _a) internal returns (address) {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;

    for (uint i=2; i<2+2*20; i+=2){
      iaddr *= 256;
      b1 = uint160(tmp[i]);
      b2 = uint160(tmp[i+1]);
      if ((b1 >= 97)&&(b1 <= 102)) b1 -= 87;
      else if ((b1 >= 48)&&(b1 <= 57)) b1 -= 48;
      if ((b2 >= 97)&&(b2 <= 102)) b2 -= 87;
      else if ((b2 >= 48)&&(b2 <= 57)) b2 -= 48;
      iaddr += (b1*16+b2);
    }

    return address(iaddr);
  }

  // Expect Oraclize result to be of form:
  // ["<issueUrl>", "<body>"]
  function checkPullRequest(string self, address claimant, string issueUrl) returns (bool) {
    var resultSlice = self.toSlice().beyond("[".toSlice()).until("]".toSlice());
    var issueUrlSlice = resultSlice.split(",".toSlice()).beyond("\"".toSlice()).until("\"".toSlice());

    if (issueUrlSlice.compare(issueUrl.toSlice()) != 0) return false;

    var body = resultSlice.beyond(" \"".toSlice()).until("\"".toSlice()).toString();
    var addrStr = parseAddressFromPullRequestBody(body);

    return toAddr(addrStr) == claimant;
  }

  // Expect pull request body to be of form:
  // <ethAddr>\r\n<message>
  function parseAddressFromPullRequestBody(string body) returns (string) {
    return body.toSlice().split("\n".toSlice()).until("\r".toSlice()).toString();
  }
}
