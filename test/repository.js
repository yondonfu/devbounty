const timeout = require('./helpers/timeout');

contract('Repository', function(accounts) {
  it('should match initial contract settings', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from: accounts[0]});

    let url = await repo.url.call();
    assert.equal(url, repoUrl, 'repo should have the correct url');

    let collateral = await repo.minCollateral.call();
    assert.equal(collateral, minCollateral, 'repo should have the correct min collateral');

    let num = await repo.penaltyNum.call();
    assert.equal(num, penaltyNum, 'repo should have the correct penalty numerator');

    let denom = await repo.penaltyDenom.call();
    assert.equal(denom, penaltyDenom, 'repo should have the correct penalty denominator');
  });

  it('should fund an issue', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from: accounts[0]});

    const issueUrl = 'https://api.github.com/repos/foo/bar/issues/1';
    const amount = web3.toWei(1, 'ether');

    await repo.fundIssue(issueUrl, {from: accounts[1], value: amount});
    let issue1 = await repo.getIssueByUrl(issueUrl);
    assert.equal(issueUrl, issue1[0], 'issue should have the correct url');
    assert.equal(amount, issue1[1], 'issue should have the correct bounty');
    assert.equal(true, issue1[2], 'issue should be initialized');

    const updatedAmount = web3.toWei(2, 'ether');

    await repo.fundIssue(issueUrl, {from: accounts[2], value: amount});
    let issue2 = await repo.getIssueByUrl(issueUrl);
    assert.equal(updatedAmount, issue2[1], 'issue should have the correct bounty');
  });

  it('should register a developer address', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, {from:accounts[0]});

    const postedCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();

    await repo.registerDev({from: accounts[1], value: postedCollateral});
    let collateral = await repo.collaterals.call(accounts[1]);
    assert.equal(collateral, postedCollateral, 'stored collaterals hould match posted collateral');
  });

  it('should open and merge a pull request', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from:accounts[0]});

    const issueUrl = 'https://api.github.com/repos/ConsenSys/truffle/issues/277';
    const amount = web3.toWei(1, 'ether');

    await repo.fundIssue(issueUrl, {from: accounts[1], value: amount});

    const postedCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();

    await repo.registerDev({from: accounts[2], value: postedCollateral});

    const openApiUrl = 'json(https://api.github.com/repos/ConsenSys/truffle/pulls/277).[url, issue_url]';
    const mergeApiUrl = 'json(https://api.github.com/repos/ConsenSys/truffle/pulls/277).merged';
    const prUrl = 'https://api.github.com/repos/ConsenSys/truffle/pulls/277';
    const initialBalance = web3.eth.getBalance(repo.address);

    let openEvent = repo.OpenCallbackSuccess({});

    openEvent.watch(async function(err, result) {
      openEvent.stopWatching();
      if (err) { throw err; }

      let pullRequest = await repo.getPullRequestByAddr(accounts[2], {from: accounts[2]});
      assert.equal(prUrl, pullRequest[0], 'pull request should have the correct url');
      assert.equal(issueUrl, pullRequest[1], 'pull request should have the correct issue url');

      let mergeEvent = repo.MergeCallbackSuccess({});

      mergeEvent.watch(async function(err, result) {
        mergeEvent.stopWatching();
        if (err) { throw err; }

        let pullRequest = await repo.getPullRequestByAddr(accounts[2], {from: accounts[2]});
        assert.equal('', pullRequest[0], 'pull request should have zeroed out url');
        assert.equal('', pullRequest[1], 'pull request should have zeroed out issue url');
      });

      await repo.mergePullRequest(mergeApiUrl, {from: accounts[2]});
    });

    await repo.openPullRequest(openApiUrl, {from: accounts[2]});

  });

});
