// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow is Ownable {
    struct Recipient {
        address id;
        uint256 amount;
        uint256 timeLock;
        bool exists;
        IERC20 currency;
    }
    using SafeMath for uint256;
    mapping(address => Recipient) public recipients;
    uint256 public depositCount;

    IERC20 public EUReToken = IERC20(0xCF487EFd00B70EaC8C28C654356Fb0E387E66D62);
    IERC20 public USDeToken = IERC20(0xcCA6b920eebFf5343cCCf386909Ec2D8Ba802bdd);

    event DepositEvent(address indexed _depositor, address indexed _recipient, uint256 _amount, IERC20 _currency);
    event ReleaseEvent(address indexed _recipient, uint256 _amount, IERC20 _currency);
    event ReclaimEvent(address indexed _recipient, uint256 _amount, IERC20 _currency);

    event DepositFailedEvent(address indexed _depositor, address indexed _recipient, uint256 _amount);
    event ReleaseFailedEvent(address indexed _recipient, uint256 _amount, IERC20 _currency);
    event ReclaimFailedEvent(address indexed _recipient, uint256 _amount, IERC20 _currency);

    event RejectEvent(string reason);

    constructor(address payable _newOwner) {
       _transferOwnership(_newOwner);
    }

    function deposit(address payable _recipient, uint _amount, string memory _tokenType) public onlyOwner {
        require(recipients[_recipient].amount == 0, "User has funds waiting already");
        require(_amount > 0, "Deposit amount cannot be zero");
        IERC20 token;
        if(keccak256(abi.encodePacked(_tokenType)) == keccak256(abi.encodePacked("EURe"))){
            token = EUReToken;
        } else if (keccak256(abi.encodePacked(_tokenType)) == keccak256(abi.encodePacked("USDe"))){
            token = USDeToken;
        } else {
            emit RejectEvent("Invalid token type");
            emit DepositFailedEvent(msg.sender, _recipient, _amount);
            return;
        }
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        uint256 balanceBefore = token.balanceOf(address(this));
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        
        if (!success || balanceBefore + _amount != balanceAfter) {
            emit RejectEvent("Deposit failed: token.transferFrom function failed");
            emit DepositFailedEvent(msg.sender, _recipient, _amount);
            return;
        }
        recipients[_recipient].id = _recipient;
        recipients[_recipient].amount = _amount;
        recipients[_recipient].timeLock = block.timestamp + 15 minutes;
        recipients[_recipient].exists = true;
        recipients[_recipient].currency = token;
        depositCount++;
        emit DepositEvent(msg.sender, _recipient, _amount, token);
    }
    
    function release(address payable _recipient) public {
        require(msg.sender == address(_recipient), "Caller is not the owner of the funds");
        require(recipients[_recipient].exists == true, "Recipient not found in the contract");
        require(block.timestamp <= recipients[_recipient].timeLock, "Time lock has passed, funds cannot be released anymore");
        IERC20 token;
        token = recipients[_recipient].currency;
        require(token.balanceOf(address(this)) >= recipients[_recipient].amount, "Insufficient token balance");
        
        uint256 value = recipients[_recipient].amount;
        recipients[_recipient].amount = 0;
        bool success = token.transfer(msg.sender, value);

        if (!success) {
            emit RejectEvent("Release failed: token.transfer function failed");
            emit ReleaseFailedEvent(_recipient, value, token);
            recipients[_recipient].amount = value;
        } else {
            emit ReleaseEvent(_recipient, value, token);
            delete recipients[_recipient];
            depositCount--;
        }
    }

    function reclaim(address payable _recipient) public onlyOwner {
        require(recipients[_recipient].exists == true, "Recipient not found in the contract");
        require(block.timestamp > recipients[_recipient].timeLock, "Time lock has not passed yet, funds cannot be reclaimed");
        IERC20 token;
        token = recipients[_recipient].currency;
        require(token.balanceOf(address(this)) >= recipients[_recipient].amount, "Insufficient token balance");

        uint256 amount = recipients[_recipient].amount;
        recipients[_recipient].amount = 0;
        bool success = token.transfer(msg.sender, amount);
        
        if (!success) {
            recipients[_recipient].amount = amount;
            emit RejectEvent("Reclaim failed: token.transfer function failed");
            emit ReclaimFailedEvent(_recipient, amount, token);
        } else {
            emit ReclaimEvent(_recipient, amount, token);
            delete recipients[_recipient];
            depositCount--;
        }
    }
    
    function balanceEURe(address _user) view public returns(uint256 _balance) {
        require(_user != address(0), "User address cannot be the zero address");
        _balance = EUReToken.balanceOf(_user);
    }

    function balanceUSDe(address _user) view public returns(uint256 _balance) {
        require(_user != address(0), "User address cannot be the zero address");
        _balance = USDeToken.balanceOf(_user);
    }
}