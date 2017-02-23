contract('Repository', function(accounts) {
  it('should match initial contract settings', async function() {
    const url = 'https://github.com/yondonfu/devbounty';
    const maintainers = [accounts[0], accounts[1]];
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const maintainerFeeNum = 1;
    const maintainerFeeDenom = 100;
    const oraclizeGas = 250000;

    let c = await Repository.new(url, maintainers, minCollateral, penaltyNum, penaltyDenom, maintainerFeeNum, maintainerFeeDenom, oraclizeGas);

    // let contractUrl = await c.url.call();
    // assert.equal(contractUrl, url, 'should have the correct url');

    // let contractMaintainer1 = await c.maintainers.call(accounts[0]);
    // assert.equal(contractMaintainer1, true, 'should have the correct first maintainer');

    // let contractMaintainer2 = await c.maintainers.call(accounts[1]);
    // assert.equal(contractMaintainer2, true, 'should have the correct second maintainer');

    // let contractMinCollateral = await c.minCollateral.call();
    // assert.equal(contractMinCollateral, minCollateral, 'should have the correct min collateral');

    // let contractPenaltyNum = await c.penaltyNum.call();
    // assert.equal(contractPenaltyNum, penaltyNum, 'should have the correct penalty numerator');

    // let contractPenaltyDenom = await c.penaltyDenom.call();
    // assert.equal(contractPenaltyDenom, penaltyDenom, 'should have the correct penalty denominator');
  });

  // it('should fund an issue', async function() {
  //   const url = 'https://github.com/yondonfu/devbounty';
  //   const maintainers = [accounts[0], accounts[1]];
  //   const minCollateral = web3.toWei(1, 'ether');
  //   const penaltyNum = 15;
  //   const penaltyDenom = 100;
  //   const maintainerFeeNum = 1;
  //   const maintainerFeeDenom = 100;
  //   const oraclizeGas = 250000;

  //   let c = await Repository.new(url, maintainers, minCollateral, penaltyNum, penaltyDenom, maintainerFeeNum, maintainerFeeDenom, oraclizeGas);

  //   const issueUrl = 'https://api.github.com/repos/yondonfu/devbounty/issues/1';
  //   const jsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/issues/1).url';
  //   const amount = web3.toWei(1, 'ether');

  //   let issueEvent = c.IssueSuccess({});

  //   issueEvent.watch(async function(err, result) {
  //     issueEvent.stopWatching();

  //     if (err) { throw err; }

  //     let issue = await c.getIssueByUrl(issueUrl);
  //     assert.equal(issue[0], issueUrl, 'issue should have the correct url');
  //     assert.equal(issue[1].toNumber(), result.args.bounty, 'issue should have the correct bounty');
  //     assert.equal(issue[2], true, 'issue should be initialized');

  //     await c.fundIssue(jsonHelper, issueUrl, {from: accounts[1], value: amount}); // Fund existing issue
  //     const updatedAmount = result.args.bounty.plus(web3.toBigNumber(amount));

  //     let fundedIssue = await c.getIssueByUrl(issueUrl);
  //     assert.equal(fundedIssue[1].toNumber(), updatedAmount.toNumber(), 'issue should have the correct updated bounty');
  //   });

  //   await c.fundIssue(jsonHelper, issueUrl, {from: accounts[0], value: amount});
  // });

  // it('should open and merge a pull request and claim payment', async function() {
  //   const url = 'https://github.com/yondonfu/devbounty';
  //   const maintainers = [accounts[0], accounts[1]];
  //   const minCollateral = web3.toWei(1, 'ether');
  //   const penaltyNum = 15;
  //   const penaltyDenom = 100;
  //   const maintainerFeeNum = 1;
  //   const maintainerFeeDenom = 100;
  //   const oraclizeGas = 400000;

  //   let c = await Repository.new(url, maintainers, minCollateral, penaltyNum, penaltyDenom, maintainerFeeNum, maintainerFeeDenom, oraclizeGas);

  //   const issueUrl = 'https://api.github.com/repos/yondonfu/devbounty/issues/1';
  //   const issueJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/issues/1).url';
  //   const amount = web3.toWei(1, 'ether');

  //   let issueEvent = c.IssueSuccess({});

  //   issueEvent.watch(async function(err, result) {
  //     issueEvent.stopWatching();

  //     if (err) { throw err; }

  //     const issueBounty = result.args.bounty.toNumber();
  //     const maintainerFee = (maintainerFeeNum * issueBounty) / maintainerFeeDenom;
  //     const devBounty = issueBounty - maintainerFee;
  //     const collateral = web3.toWei(1, 'ether');

  //     const prUrl = 'https://api.github.com/yondonfu/devbounty/pulls/1';
  //     const openJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).[issue_url, body]';
  //     const mergeJsonHelper = 'json(https://api.github.com/repos/yondonfu/devbounty/pulls/1).merged';

  //     let openedPullRequestEvent = c.OpenedPullRequestSuccess({});

  //     openedPullRequestEvent.watch(async function(err, result) {
  //       openedPullRequestEvent.stopWatching();

  //       if (err) { throw err; }

  //       let pullRequest = await c.getPullRequestByUrl(prUrl, {from: accounts[48]});
  //       assert.equal(pullRequest[0], prUrl, 'pull request should have the correct url');
  //       assert.equal(pullRequest[1], issueUrl, 'pull request should have the correct issue url');

  //       let mergedPullRequestEvent = c.MergedPullRequestSuccess({});

  //       mergedPullRequestEvent.watch(async function(err, result) {
  //         mergedPullRequestEvent.stopWatching();

  //         if (err) { throw err; }

  //         let pullRequest = await c.getPullRequestByUrl(prUrl, {from: accounts[48]});
  //         assert.equal(pullRequest[0], '', 'pull request should have zeroed out url');
  //         assert.equal(pullRequest[1], '', 'pull request should have zeroed out issue url');

  //         assert.equal(result.args.devBounty.toNumber(), devBounty, 'developer bounty should be correct');
  //         assert.equal(result.args.maintainerFee.toNumber(), maintainerFee, 'maintainer fee should be correct');

  //         const initialMaintainerBalance = web3.eth.getBalance(accounts[0]).toNumber();
  //         const initialDevBalance = web3.eth.getBalance(accounts[48]).toNumber();

  //         await c.claimBounty({from: accounts[0]});

  //         const maintainerBalance = web3.eth.getBalance(accounts[0]).toNumber();

  //         assert(Math.abs(maintainerBalance - initialMaintainerBalance - maintainerFee) < 1e16, 'maintainer should claim the correct fee amount');

  //         await c.claimBounty({from: accounts[48]});

  //         const devBalance = web3.eth.getBalance(accounts[48]).toNumber();

  //         assert(Math.abs(devBalance - initialDevBalance - devBounty) < 1e16, 'developer should claim the correct bounty amount');
  //       });

  //       await c.mergePullRequest(mergeJsonHelper, prUrl, {from: accounts[0], value: collateral});
  //     });

  //     await c.openPullRequest(openJsonHelper, prUrl, issueUrl, {from: accounts[48], value: collateral});
  //   });

  //   await c.fundIssue(issueJsonHelper, issueUrl, {from: accounts[0], value: amount});
  // });

});
