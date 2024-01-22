// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Registrator is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public lockBlocks;

    IERC20 public tokenContract;

    struct Lock {
        uint256 amount;
        uint256 unlockAt;
    }

    struct Data {
        uint256 penalty;
        Lock[] locks;
    }

    mapping(address => Data) public data;

    function lock(uint256 _amount) external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), _amount));
        data[msg.sender].locks.push(Lock(_amount, block.number + lockBlocks));
    }

    function lockFor(address _address, uint256 _amount) external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), _amount));
        data[_address].locks.push(Lock(_amount, block.number + lockBlocks));
    }

    function unlock(uint256 _upto) external whenNotPaused {
        require(_upto > 0, "UpTo parameter must be greater than 0");
    
        uint256 requested = _upto;
        uint256 unlocked = 0;
        uint consumedSize = 0;
        uint[] memory consumed = new uint[](data[msg.sender].locks.length);
        for (uint i = 0; i < data[msg.sender].locks.length; i++) {
            if (data[msg.sender].locks[i].unlockAt < block.number) {
                if (requested > 0) {
                    if (data[msg.sender].locks[i].amount > requested) {
                        data[msg.sender].locks[i].amount -= requested;
                        unlocked += requested;
                        requested = 0;
                    } else {
                        requested -= data[msg.sender].locks[i].amount;
                        unlocked += data[msg.sender].locks[i].amount;
                        consumed[consumedSize] = i;
                        consumedSize++;
                    }
                }
            }
        }

        uint removed = 0;
        for (uint i = 0; i < consumedSize; i++) {
            uint adjustedIndex = consumed[i] - removed;
            require(adjustedIndex < data[msg.sender].locks.length, "Index out of bounds");
            for (uint j = adjustedIndex; j < data[msg.sender].locks.length - 1; j++) {
                data[msg.sender].locks[j] = data[msg.sender].locks[j + 1];
            }
            data[msg.sender].locks.pop();
            removed++;
        }

        require(tokenContract.balanceOf(address(this)) >= unlocked, "Insufficient contract token balance");
        require(tokenContract.transfer(msg.sender, unlocked), "Token transfer failed");
    }

    function setPenalty(address _account, uint256 _value)
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        data[_account].penalty = _value;
    }


    function setLockBlocks(uint256 _value) 
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        require(_value > 0);
        lockBlocks = _value;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _tokenAddress, 
        address payable _operator
    ) initializer public {
        tokenContract = IERC20(_tokenAddress);
        
        lockBlocks = 180 * 24 * 60 * 5; // 12sec avg per block over 180 days

        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, _operator);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}
}
