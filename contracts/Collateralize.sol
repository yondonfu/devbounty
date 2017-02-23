pragma solidity ^0.4.6;

contract Collateralize {
  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;

  mapping(address => uint) public collaterals;

  modifier requiresCollateral() {
    if (msg.value < minCollateral) throw;
    _;
  }

  function withdrawCollateral() external {
    address payee = msg.sender;

    uint collateral = collaterals[payee];

    if (collateral == 0) throw;
    if (this.balance < collateral) throw;

    collaterals[payee] = 0;

    if (!payee.send(collateral)) {
      collaterals[payee] = collateral;
    }
  }

  function calcPenalty(uint amount) internal constant returns (uint) {
    return (amount * penaltyNum) / penaltyDenom;
  }
}
