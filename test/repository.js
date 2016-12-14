contract('Repository', function(accounts) {
  it('should match initial contract settings', function(done) {
    var repoUrl = 'https://github.com/foo/bar';
    var minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    var penaltyNum = 15;
    var penaltyDenom = 100;

    Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, { from: accounts[0] }).then(function(repo) {
      repo.url.call().then(function(url) {
        assert.equal(url, repoUrl, 'repo should have the correct url');

        return repo.minCollateral.call();
      }).then(function(collateral) {
        assert.equal(collateral, minCollateral, 'repo should have the correct min collateral');

        return repo.penaltyNum.call();
      }).then(function(num) {
        assert.equal(num, penaltyNum, 'repo should have the correct penalty numerator');

        return repo.penaltyDenom.call();
      }).then(function(denom) {
        assert.equal(denom, penaltyDenom, 'repo should have the correct penalty denominator');

        done();
      }).catch(done);
    }).catch(done);
  });

  it('should fund an issue', function(done) {
    var repoUrl = 'https://github.com/foo/bar';
    var minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    var penaltyNum = 15;
    var penaltyDenom = 100;

    Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, { from: accounts[0] }).then(function(repo) {
      var issueUrl = 'https://api.github.com/repos/foo/bar/issues/1';
      var amount = web3.toWei(1, 'ether');

      repo.fundIssue(issueUrl, { from: accounts[1], value: amount }).then(function() {
        return repo.getIssueByUrl(issueUrl);
      }).then(function(issue) {
        assert.equal(issueUrl, issue[0], 'issue should have the correct url');
          assert.equal(amount, issue[1], 'issue should have the correct bounty');

        repo.fundIssue(issueUrl, { from: accounts[2], value: amount }).then(function() {
          return repo.getIssueByUrl(issueUrl);
        }).then(function(updatedIssue) {
          var updatedAmount = web3.toWei(2, 'ether');

          assert.equal(issueUrl, updatedIssue[0], 'updated issue should have the correct url');
          assert.equal(updatedAmount, updatedIssue[1], 'updated issue should have the correct bounty');

          done();
        }).catch(done);
      }).catch(done);
    }).catch(done);
  });

  it('should register a developer address', function(done) {
    var repoUrl = 'https://github.com/foo/bar';
    var minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    var penaltyNum = 15;
    var penaltyDenom = 100;

    Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, { from: accounts[0] }).then(function(repo) {
      var postedCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();

      repo.registerDev({ from: accounts[1], value: postedCollateral }).then(function() {
        return repo.collaterals.call(accounts[1]);
      }).then(function(collateral) {
        assert.equal(collateral, postedCollateral, 'stored collateral should match posted collateral');

        done();
      }).catch(done);
    }).catch(done);
  });

});
