contract('DevBounty', function(accounts) {
  it('should match initial contract settings', async function() {
    const minCollateral = web3.toWei(1, 'ether');
    const penaltyNum = 15;
    const penaltyDenom = 100;
    const oraclizeGas = 250000;

    let c = await DevBounty.new(minCollateral, penaltyNum, penaltyDenom, oraclizeGas);

    // let contractMinCollateral = await c.minCollateral.call();
    // assert.equal(contractMinCollateral, minCollateral, 'should have the correct min collateral');

    // let contractPenaltyNum = await c.penaltyNum.call();
    // assert.equal(contractPenaltyNum, penaltyNum, 'should have the correct penalty numerator');

    // let contractPenaltyDenom = await c.penaltyDenom.call();
    // assert.equal(contractPenaltyDenom, penaltyDenom, 'should have the correct penalty denominator');

  });
});
