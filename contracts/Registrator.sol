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

    struct Data {
        uint256 amount;
        uint256 unlockAt;
        address unlockTo;
    }
    struct Registration {
        uint256 penalty;
        Data[] data;
    }

    mapping(address => Registration) registrations;

    event Registered(address indexed _account);

    function getRegistration(address _address) public view returns (Registration memory) {
        return registrations[_address];
    }

    function register(address _address) external whenNotPaused {
        require(tokenContract.transferFrom(msg.sender, address(this), currentLockSize));
        
        registrations[_address].data.push(Data(currentLockSize, block.number + lockBlocks, msg.sender));
        
        emit Registered(_address);
    }

    function unregister(address _address, uint256 _upto) external whenNotPaused {
        require(_upto > 0, "UpTo parameter must be greater than 0");
    
        uint256 requested = _upto;
        uint256 unlocked = 0;
        uint consumedSize = 0;
        uint[] memory consumed = new uint[](registrations[_address].data.length);
        for (uint i = 0; i < registrations[_address].data.length; i++) {

            if ((registrations[_address].data[i].unlockAt < block.number) && (registrations[_address].data[i].unlockTo == msg.sender)) {
                if (requested > 0) {
                    if (registrations[_address].data[i].amount > requested) {
                        registrations[_address].data[i].amount -= requested;
                        unlocked += requested;
                        requested = 0;
                    } else {
                        requested -= registrations[_address].data[i].amount;
                        unlocked += registrations[_address].data[i].amount;

                        consumed[consumedSize] = i;
                        consumedSize++;
                    }
                }
            }

        }

        require(unlocked > 0, "No unlockables found");
        
        require(tokenContract.balanceOf(address(this)) >= unlocked, "Insufficient contract token balance");
        require(tokenContract.transfer(msg.sender, unlocked), "Token transfer failed");

        uint removed = 0;
        for (uint i = 0; i < consumedSize; i++) {
            uint adjustedIndex = consumed[i] - removed;
            require(adjustedIndex < registrations[_address].data.length, "Index out of bounds");

            for (uint j = adjustedIndex; j < registrations[_address].data.length - 1; j++) {
                registrations[_address].data[j] = registrations[_address].data[j + 1];
            }
            registrations[_address].data.pop();
            removed++;
        }

        if (registrations[_address].data.length == 0) {
            delete registrations[_address];
        }
    }

    function setPenalty(address _address, uint256 _value)
        external 
        whenNotPaused 
        onlyRole(OPERATOR_ROLE)
    {
        registrations[_address].penalty = _value;
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
