pragma solidity ^0.4.6;

contract ClaimableBounty {
  mapping(address => uint) public claimableBounties; // developer address => claimable bounty amount

  function claimBounty() external {
    address payee = msg.sender;

    uint bounty = claimableBounties[payee];

    if (bounty == 0) throw;
    if (this.balance < bounty) throw;

    claimableBounties[payee] = 0;
    if (!payee.send(bounty)) {
      claimableBounties[payee] = bounty;
    }
  }
}
