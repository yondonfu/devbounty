contract('DevBounty', function(accounts) {
  it('should match initial contract settings', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {gas: 5300000});

    let contractMinCollateral = await c.minCollateral.call();
    assert.equal(contractMinCollateral, minCollateral, 'should have the correct min collateral');

    let contractPenaltyNum = await c.penaltyNum.call();
    assert.equal(contractPenaltyNum, penaltyNum, 'should have the correct penalty numerator');

    let contractPenaltyDenom = await c.penaltyDenom.call();
    assert.equal(contractPenaltyDenom, penaltyDenom, 'should have the correct penalty denominator');

  });

  it('should register a repository', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 5000000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas, {gas: 5300000});

    let maintainerEvent = c.MaintainerSuccess({});

    maintainerEvent.watch(async function(err, result) {
      maintainerEvent.stopWatching();

      if (err) { throw err; }


    });

    const url = 'https://github.com/yondonfu/devbounty/blob/master/PROOF.md';
    const jsonHelper = 'https://raw.githubusercontent.com/yondonfu/devbounty/master/PROOF.md';
    const maintainerFeeNum = 1;
    const maintainerFeeDenom = 100;
    const collateral = web3.toWei(1, 'ether');

    await c.registerRepository(jsonHelper, url, minCollateral, penaltyNum, penaltyDenom, maintainerFeeNum, maintainerFeeDenom, oraclizeGas, {from: accounts[0], value: collateral});
  });
});
