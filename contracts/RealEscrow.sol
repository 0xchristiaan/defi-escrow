// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Escrow {
  address admin;
  uint256 public totalBalance;

  // this is the P2PM erc20 contract address
  address constant p2pmAddress = 0xd9145CCE52D386f254917e481eB44e9943F39138;

  struct Transaction {
    address buyer;
    uint256 amount;
    bool locked;
    bool spent;
  }

  mapping(address => mapping(address => Transaction)) public balances;

  modifier onlyAdmin {
    require(msg.sender == admin, "Only admin can unlock escrow.");
    _;
  }

  constructor() {
    admin = msg.sender;
  }

  // seller accepts a trade, erc20 tokens
  // get moved to the escrow (this contract)
  function accept(address _tx_id, address _buyer, uint256 _amount) external returns (uint256) {
    token.transferFrom(msg.sender, address(this), _amount);
    totalBalance += _amount;
    balances[msg.sender][_tx_id].amount = _amount;
    balances[msg.sender][_tx_id].buyer = _buyer;
    balances[msg.sender][_tx_id].locked = true;
    balances[msg.sender][_tx_id].spent = false;
    return token.balanceOf(msg.sender);
  }

  // retrieve current state of transaction in escrow
  function transaction(address _seller, address _tx_id) external view returns (uint256, bool, address) {
    return ( balances[_seller][_tx_id].amount, balances[_seller][_tx_id].locked, balances[_seller][_tx_id].buyer );
  }

  // admin unlocks tokens in escrow for a transaction
  function release(address _tx_id, address _seller) onlyAdmin external returns(bool) {
    balances[_seller][_tx_id].locked = false;
    return true;
  }

  // seller is able to withdraw unlocked tokens
  function withdraw(address _tx_id) external returns(bool) {
    require(balances[msg.sender][_tx_id].locked == false, 'This escrow is still locked');
    require(balances[msg.sender][_tx_id].spent == false, 'Already withdrawn');

    P2PM token = P2PM(p2pmAddress);
    token.transfer(msg.sender, balances[msg.sender][_tx_id].amount);

    totalBalance -= balances[msg.sender][_tx_id].amount;
    balances[msg.sender][_tx_id].spent = true;
    return true;
  }

  // admin can send funds to buyer if dispute resolution is in buyer's favor
  function resolveToBuyer(address _seller, address _tx_id) onlyAdmin external returns(bool) {
    P2PM token = P2PM(p2pmAddress);
    token.transfer(balances[_seller][_tx_id].buyer, balances[msg.sender][_tx_id].amount);

    balances[_seller][_tx_id].spent = true;
    totalBalance -= balances[_seller][_tx_id].amount;
    return true;
  }


}