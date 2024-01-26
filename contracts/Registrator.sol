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
    uint256 public currentLockSize;

    IERC20 public tokenContract;

    struct LockData {
        uint256[] amount;
        uint256[] unlockAt;
    }

    mapping(address => LockData) locks;
    mapping(address => uint256) public penalties;

    event LockRegistered(address indexed _account);

    function getLock(address _address) public view returns (LockData memory) {
        return locks[_address];
    }

    function lock() external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), currentLockSize));
        locks[msg.sender].amount.push(currentLockSize);
        locks[msg.sender].unlockAt.push(block.number + lockBlocks);
        emit LockRegistered(msg.sender);
    }

    function lockFor(address _address) external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), currentLockSize));
        locks[_address].amount.push(currentLockSize);
        locks[_address].unlockAt.push(block.number + lockBlocks);
        emit LockRegistered(_address);
    }

    function unlock(uint256 _upto) external whenNotPaused {
        require(_upto > 0, "UpTo parameter must be greater than 0");
    
        uint256 requested = _upto;
        uint256 unlocked = 0;
        uint consumedSize = 0;
        uint[] memory consumed = new uint[](locks[msg.sender].amount.length);
        for (uint i = 0; i < locks[msg.sender].amount.length; i++) {
            if (locks[msg.sender].unlockAt[i] < block.number) {
                if (requested > 0) {
                    if (locks[msg.sender].amount[i] > requested) {
                        locks[msg.sender].amount[i] -= requested;
                        unlocked += requested;
                        requested = 0;
                    } else {
                        requested -= locks[msg.sender].amount[i];
                        unlocked += locks[msg.sender].amount[i];
                        consumed[consumedSize] = i;
                        consumedSize++;
                    }
                }
            }
        }

        require(unlocked > 0, "No unlockables found");
        require(tokenContract.balanceOf(address(this)) >= unlocked, "Insufficient contract token balance");
        require(tokenContract.transfer(msg.sender, unlocked), "Token transfer failed");

        require(locks[msg.sender].amount.length == locks[msg.sender].unlockAt.length, "Data consistency failure");
        uint removed = 0;
        for (uint i = 0; i < consumedSize; i++) {
            uint adjustedIndex = consumed[i] - removed;
            require(adjustedIndex < locks[msg.sender].amount.length, "Index out of bounds");
            require(adjustedIndex < locks[msg.sender].unlockAt.length, "Index out of bounds");
            for (uint j = adjustedIndex; j < locks[msg.sender].amount.length - 1; j++) {
                locks[msg.sender].amount[j] = locks[msg.sender].amount[j + 1];
                locks[msg.sender].unlockAt[j] = locks[msg.sender].amount[j + 1];
            }
            locks[msg.sender].amount.pop();
            locks[msg.sender].unlockAt.pop();
            removed++;
        }

        if (locks[msg.sender].amount.length == 0) {
            delete locks[msg.sender];
        }
    }

    function setPenalty(address _account, uint256 _value)
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        penalties[_account] = _value;
    }

    function setLockSize(uint256 _value)
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        require(_value > 0, "Lock size has to be non-zero");
        currentLockSize = _value;
    }


    function setLockBlocks(uint256 _value) 
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        require(_value > 0, "Lock duration has to be non-zero");
        lockBlocks = _value;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _tokenAddress, 
        address payable _operator,
        uint256 _lockBlocks,
        uint256 _lockSize
    ) initializer public {
        tokenContract = IERC20(_tokenAddress);
        
        lockBlocks = _lockBlocks;
        currentLockSize = _lockSize;

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
