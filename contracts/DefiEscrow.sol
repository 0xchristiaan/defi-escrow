pragma solidity ^0.8.0;

import "@OpenZeppelin/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract DefiEscrow {
    using SafeMath for uint256;

    ERC20 public usdcToken;
    address public aveeToken;
    uint256 public releaseTime;
    address public beneficiary;

    constructor(
        address _usdcToken,
        address _aveeToken,
        uint256 _releaseTime,
        address _beneficiary
    ) public {
        usdcToken = ERC20(_usdcToken);
        aveeToken = _aveeToken;
        releaseTime = _releaseTime;
        beneficiary = _beneficiary;
    }

    function deposit(uint256 _value) public payable {
        require(msg.value == _value, "Incorrect deposit value");
        usdcToken.transferFrom(msg.sender, address(this), _value);
        aveeToken.call(bytes4(keccak256("stake(uint256)")), _value);
    }

    function release() public {
        require(now >= releaseTime, "Release time has not been reached");
        beneficiary.transfer(address(this).balance);
    }
}