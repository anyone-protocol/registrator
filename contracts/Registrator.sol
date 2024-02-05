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
        address[] unlockTo;
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
        locks[msg.sender].unlockTo.push(msg.sender);
        emit LockRegistered(msg.sender);
    }

    function lockFor(address _address) external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), currentLockSize));
        locks[_address].amount.push(currentLockSize);
        locks[_address].unlockAt.push(block.number + lockBlocks);
        locks[_address].unlockTo.push(msg.sender);
        emit LockRegistered(_address);
    }

    function unlock(address _address, uint256 _upto) external whenNotPaused {
        require(_upto > 0, "UpTo parameter must be greater than 0");
    
        uint256 requested = _upto;
        uint256 unlocked = 0;
        uint consumedSize = 0;
        uint[] memory consumed = new uint[](locks[_address].amount.length);
        for (uint i = 0; i < locks[_address].amount.length; i++) {
            if ((locks[_address].unlockAt[i] < block.number) && (locks[_address].unlockTo[i] == msg.sender)) {
                if (requested > 0) {
                    if (locks[_address].amount[i] > requested) {
                        locks[_address].amount[i] -= requested;
                        unlocked += requested;
                        requested = 0;
                    } else {
                        requested -= locks[_address].amount[i];
                        unlocked += locks[_address].amount[i];

                        consumed[consumedSize] = i;
                        consumedSize++;
                    }
                }
            }
        }

        require(unlocked > 0, "No unlockables found");
        
        require(tokenContract.balanceOf(address(this)) >= unlocked, "Insufficient contract token balance");
        require(tokenContract.transfer(msg.sender, unlocked), "Token transfer failed");

        require(locks[_address].amount.length == locks[_address].unlockAt.length, "Data consistency failure 1");
        require(locks[_address].amount.length == locks[_address].unlockTo.length, "Data consistency failure 2");

        uint removed = 0;
        for (uint i = 0; i < consumedSize; i++) {
            uint adjustedIndex = consumed[i] - removed;
            require(adjustedIndex < locks[_address].amount.length, "Index out of bounds of amount");
            require(adjustedIndex < locks[_address].unlockAt.length, "Index out of bounds of unlockAt");
            require(adjustedIndex < locks[_address].unlockTo.length, "Index out of bounds of unlockTo");

            for (uint j = adjustedIndex; j < locks[_address].amount.length - 1; j++) {
                locks[_address].amount[j] = locks[_address].amount[j + 1];
                locks[_address].unlockAt[j] = locks[_address].unlockAt[j + 1];
                locks[_address].unlockTo[j] = locks[_address].unlockTo[j + 1];
            }
            locks[_address].amount.pop();
            locks[_address].unlockAt.pop();
            locks[_address].unlockTo.pop();
            removed++;
        }

        if (locks[_address].amount.length == 0) {
            delete locks[_address];
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
