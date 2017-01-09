const timeout = require('./helpers/timeout');

contract('DevBounty', function(accounts) {
  it('should match initial contract settings', async function() {
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from: accounts[0]});

    let collateral = await c.minCollateral.call();
    assert.equal(collateral, minCollateral, 'contract should have the correct min collateral');

    let num = await c.penaltyNum.call();
    assert.equal(num, penaltyNum, 'contract should have the correct penalty numerator');

    let denom = await c.penaltyDenom.call();
    assert.equal(denom, penaltyDenom, 'contract should have the correct penalty denominator');
  });

  it('should fund an issue', async function() {
    const minCollateral = web3.toBigNumber(web3.toWei(1, 'ether')).toNumber();
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from: accounts[0]});

    const issueUrl = 'https://api.github.com/repos/foo/bar/issues/1';
    const issueJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/issues/1).url';
    const amount = web3.toWei(1, 'ether');

    let fundIssueEvent = c.FundIssueCallbackSuccess({});

    fundIssueEvent.watch(async function(err, result) {
      fundIssueEvent.stopWatching();
      if (err) { throw err; }

      let issue1 = await c.getIssueByUrl(issueUrl);
      assert.equal(issueUrl, issue1[0], 'issue should have the correct url');
      assert.equal(result.args.updatedBounty.toNumber(), issue1[1].toNumber(), 'issue should have the correct bounty');
      assert.equal(true, issue1[2], 'issue should be initialized');

      await c.fundIssue(issueUrl, issueJsonHelper, {from: accounts[2], value: amount});
      const updatedAmount = result.args.updatedBounty.plus(web3.toBigNumber(amount));

      let issue2 = await c.getIssueByUrl(issueUrl);
      assert.equal(updatedAmount.toNumber(), issue2[1].toNumber(), 'issue should have the correct bounty');
    });

    await c.fundIssue(issueUrl, issueJsonHelper, {from: accounts[1], value: amount});
  });

  it('should open and merge a pull request and claim payment', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 400000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {from:accounts[0]});

    const issueUrl = 'https://api.github.com/repos/yondonfu/devbounty/issues/1';
    const issueJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/issues/1).url';
    const amount = web3.toWei(1, 'ether');

    let fundIssueEvent = c.FundIssueCallbackSuccess({});

    fundIssueEvent.watch(async function(err, result) {
      fundIssueEvent.stopWatching();
      if (err) { throw err; }

      const issueBounty = result.args.updatedBounty;

      const prUrl = 'https://api.github.com/repos/yondonfu/devbounty/pulls/1';
      const openJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).[issue_url, body]';
      const mergeJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).merged';

      let openEvent = c.OpenCallbackSuccess({});

      openEvent.watch(async function(err, result) {
        openEvent.stopWatching();
        if (err) { throw err; }

        let pullRequest = await c.getPullRequestByAddr(accounts[9], {from: accounts[9]});
        assert.equal(prUrl, pullRequest[0], 'pull request should have the correct url');
        assert.equal(issueUrl, pullRequest[1], 'pull request should have the correct issue url');

        let mergeEvent = c.MergeCallbackSuccess({});

        mergeEvent.watch(async function(err, result) {
          mergeEvent.stopWatching();
          if (err) { throw err; }

          let pullRequest = await c.getPullRequestByAddr(accounts[9], {from: accounts[9]});
          assert.equal('', pullRequest[0], 'pull request should have zeroed out url');
          assert.equal('', pullRequest[1], 'pull request should have zeroed out issue url');

          assert.equal(result.args.updatedClaimableBounty.toNumber(), issueBounty.toNumber(), 'claimable bounty should match issue bounty');

        });

        await c.mergePullRequest(prUrl, mergeJsonHelper, {from: accounts[9]});
        console.log('merged');
      });

      const postedCollateral = web3.toWei(1, 'ether');
      await c.openPullRequest(prUrl, openJsonHelper, {from: accounts[9], value: postedCollateral});
      console.log('opened');
    });

    await c.fundIssue(issueUrl, issueJsonHelper, {from: accounts[1], value: amount});
    console.log('funded');
  });

});
