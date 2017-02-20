pragma solidity ^0.4.6;

contract Collateralize {
  mapping(address => uint) public collaterals;

  uint public minCollateral;
  uint public penaltyNum;
  uint public penaltyDenom;

  modifier requiresCollateral() {
    if (msg.value < minCollateral) throw;
    _;
  }

  function withdrawCollateral() external {
    uint collateral = collaterals[msg.sender];

    if (collateral == 0) throw;
    if (this.balance < collateral) throw;

    collaterals[msg.sender] = 0;

    if (!msg.sender.send(collateral)) {
      collaterals[msg.sender] = collateral;
    }
  }

  function calcPenalty(uint amount) internal constant returns (uint) {
    return (amount * penaltyNum) / penaltyDenom;
  }
}
