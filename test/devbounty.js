contract('DevBounty', function(accounts) {
  it('should match initial contract settings', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {gas: 5000000});

    let contractMinCollateral = await c.minCollateral.call();
    assert.equal(contractMinCollateral, minCollateral, 'should have the correct min collateral');

    let contractPenaltyNum = await c.penaltyNum.call();
    assert.equal(contractPenaltyNum, penaltyNum, 'should have the correct penalty numerator');

    let contractPenaltyDenom = await c.penaltyDenom.call();
    assert.equal(contractPenaltyDenom, penaltyDenom, 'should have the correct penalty denominator');

  });

  it('should register a repository, fund an issue, open/merge a pull request and claim bounties', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {gas: 5000000});

    const collateral = web3.toWei(1, 'ether');

    // registerRepository params
    const maintainerJsonHelper = 'https://raw.githubusercontent.com/yondonfu/devbounty/master/PROOF.md';
    const repoUrl = 'https://github.com/yondonfu/devbounty';
    const proofUrl = 'https://raw.githubusercontent.com/yondonfu/devbounty/master/PROOF.md';
    const repoMinCollateral = web3.toWei(1, 'ether');
    const repoPenaltyNum = 15;
    const repoPenaltyDenom = 100;
    const maintainerFeeNum = 2;
    const maintainerFeeDenom = 100;

    // fundIssue params
    const issueJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/issues/1).url';
    const issueUrl = 'https://api.github.com/repos/yondonfu/devbounty/issues/1';
    const amount = web3.toWei(1, 'ether');

    let maintainerEvent = c.MaintainerSuccess({});

    maintainerEvent.watch(async function(err, result) {
      maintainerEvent.stopWatching();

      if (err) { throw err; }

      let issueEvent = c.IssueSuccess({});

      issueEvent.watch(async function(err, result) {
        issueEvent.stopWatching();

        if (err) { throw err; }

        const issueBounty = result.args.bounty.toNumber();
        const maintainerFee = (issueBounty * maintainerFeeNum) / maintainerFeeDenom;
        const devBounty = issueBounty - maintainerFee;

        // openPullRequest and mergePullRequest params
        const openJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).[issue_url, body]';
        const mergeJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).merged';
        const prUrl = 'https://api.github.com/repos/yondonfu/devbounty/pulls/1';

        let openedPullRequestEvent = c.OpenedPullRequestSuccess({});

        openedPullRequestEvent.watch(async function(err, result) {
          openedPullRequestEvent.stopWatching();

          if (err) { throw err; }

          let pullRequest = await c.getPullRequestByUrl(repoUrl, prUrl, {from: accounts[48]});

          assert.equal(pullRequest[0], accounts[48], 'pull request should have the correct owner');
          assert.equal(pullRequest[1], issueUrl, 'pull request should have the correct issue url');
          assert.equal(pullRequest[2], true, 'pull request should be initialized');

          let mergedPullRequestEvent = c.MergedPullRequestSuccess({});

          mergedPullRequestEvent.watch(async function(err, result) {
            mergedPullRequestEvent.stopWatching();

            if (err) { throw err; }

            const initialMaintainerBalance = web3.eth.getBalance(accounts[0]).toNumber();
            const initialDevBalance = web3.eth.getBalance(accounts[48]).toNumber();

            await c.claimBounty(repoUrl, {from: accounts[0]});

            const maintainerBalance = web3.eth.getBalance(accounts[0]).toNumber();

            assert(Math.abs(maintainerBalance - initialMaintainerBalance - maintainerFee) < 1e16, 'maintainer should claim the correct fee amount');

            await c.claimBounty(repoUrl, {from: accounts[48]});

            const devBalance = web3.eth.getBalance(accounts[48]).toNumber();

            assert(Math.abs(devBalance - initialDevBalance - devBounty) < 1e16, 'developer should claim the correct bounty amount');
          });

          await c.mergePullRequest(mergeJsonHelper, repoUrl, prUrl, {from: accounts[0], value: collateral});
        });

        await c.openPullRequest(openJsonHelper, repoUrl, prUrl, issueUrl, {from: accounts[48], value: collateral});
      });

      await c.fundIssue(issueJsonHelper, repoUrl, issueUrl, {from: accounts[0], value: amount});
    });

    await c.registerRepository(maintainerJsonHelper, repoUrl, proofUrl, repoMinCollateral, repoPenaltyNum, repoPenaltyDenom, maintainerFeeNum, maintainerFeeDenom, {from: accounts[0], value: collateral});
  });
});
