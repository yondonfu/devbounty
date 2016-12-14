contract('Repository', function(accounts) {
  it('should match initial contract settings', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, {from: accounts[0]});

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

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, {from: accounts[0]});

    const issueUrl = 'https://api.github.com/repos/foo/bar/issues/1';
    const amount = web3.toWei(1, 'ether');

    let fundIssue1 = await repo.fundIssue(issueUrl, {from: accounts[1], value: amount});
    let issue1 = await repo.getIssueByUrl(issueUrl);
    assert.equal(issueUrl, issue1[0], 'issue should have the correct url');
    assert.equal(amount, issue1[1], 'issue should have the correct bounty');

    const updatedAmount = web3.toWei(2, 'ether');

    let fundIssue2 = await repo.fundIssue(issueUrl, {from: accounts[2], value: amount});
    let issue2 = await repo.getIssueByUrl(issueUrl);
    assert.equal(issueUrl, issue2[0], 'issue should have the correct url');
    assert.equal(updatedAmount, issue2[1], 'issue should have the correct bounty');
  });

  it('should register a developer address', async function() {
    const repoUrl = 'https://github.com/foo/bar';
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;

    let repo = await Repository.new(repoUrl, minCollateral, penaltyNum, penaltyDenom, {from:accounts[0]});

    const postedCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();

    let registerDev = await repo.registerDev({from: accounts[1], value: postedCollateral});
    let collateral = await repo.collaterals.call(accounts[1]);
    assert.equal(collateral, postedCollateral, 'stored collaterals hould match posted collateral');
  });

});
