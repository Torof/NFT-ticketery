// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "./EventTicket.sol";
import "./TicketPlatform.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Organization
 * @notice Contract managing organization operations and event creation
 * @dev Implements token payments and custom errors with require statements
 */
contract Organization is Pausable {
    // Custom Errors for validation and access control
    error NotOwner(address caller);
    error NotPlatform(address caller);
    error InvalidOwner(address owner);
    error InvalidPlatform(address platform);
    error InvalidDeadline(uint256 deadline, uint256 current);
    error InvalidSupply(uint256 supply);
    error NotEventOwner(address eventAddress);
    error EventAlreadyClosed(address eventAddress);
    error InvalidPrice(uint256 price);
    error TokenTransferFailed(address token, address from, address to, uint256 amount);
    
    // State variables
    address public owner;
    address public immutable platformContract;
    string public bannerIPFS;
    
    // Events for subgraph indexing
    event BannerUpdated(
        string newBannerHash,
        uint256 timestamp
    );
    
    event EventCreated(
        address indexed eventAddress,
        string eventURI,
        uint256 ticketPrice,
        uint256 maxSupply,
        uint256 deadline,
        uint256 timestamp
    );
    
    event EventClosed(
        address indexed eventAddress,
        uint256 timestamp
    );
    
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );
    
    event TokensReceived(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner(msg.sender));
        _;
    }
    
    modifier onlyPlatform() {
        require(msg.sender == platformContract, NotPlatform(msg.sender));
        _;
    }

    constructor(address _owner, address _platformContract) {
        require(_owner != address(0), InvalidOwner(_owner));
        require(_platformContract != address(0), InvalidPlatform(_platformContract));
        owner = _owner;
        platformContract = _platformContract;
    }

    /**
     * @notice Updates organization's banner IPFS hash
     * @dev Only callable by organization owner when not paused
     */
    function updateBanner(string memory newBannerHash) external onlyOwner whenNotPaused {
        bannerIPFS = newBannerHash;
        emit BannerUpdated(newBannerHash, block.timestamp);
    }

    /**
     * @notice Creates a new event using the platform's factory
     * @dev Automatically registers event with platform and configures token payments
     * @param eventURI The IPFS URI containing event metadata
     * @param ticketPrice The price per ticket in payment token units
     * @param deadline The timestamp after which tickets can't be sold/transferred
     * @param maxSupply The maximum number of tickets that can be minted
     */
    function createEvent(
        string memory eventURI,
        uint256 ticketPrice,
        uint256 deadline,
        uint256 maxSupply
    ) external onlyOwner whenNotPaused returns (address) {
        require(deadline > block.timestamp, InvalidDeadline(deadline, block.timestamp));
        require(maxSupply > 0, InvalidSupply(maxSupply));
        require(ticketPrice > 0, InvalidPrice(ticketPrice));
        
        // Create event through factory
        address newEvent = TicketPlatform(platformContract).eventFactory().createEvent(
            address(this),
            eventURI,
            ticketPrice,
            deadline,
            maxSupply,
            platformContract
        );
        
        // Register event with platform
        TicketPlatform(platformContract).registerEvent(
            newEvent,
            eventURI,
            ticketPrice,
            maxSupply,
            deadline
        );
        
        emit EventCreated(
            newEvent,
            eventURI,
            ticketPrice,
            maxSupply,
            deadline,
            block.timestamp
        );
        
        return newEvent;
    }

    /**
     * @notice Closes an event, preventing further ticket operations
     * @dev Updates platform registries and event status
     */
    function closeEvent(address eventAddress) external onlyOwner whenNotPaused {
        require(
            EventTicket(eventAddress).organizationContract() == address(this),
            NotEventOwner(eventAddress)
        );
        require(!EventTicket(eventAddress).isClosed(), EventAlreadyClosed(eventAddress));
        
        EventTicket(eventAddress).close();
        TicketPlatform(platformContract).markEventAsClosed(eventAddress);
        
        emit EventClosed(eventAddress, block.timestamp);
    }

    /**
     * @notice Updates ticket price for an event
     * @dev Only callable by owner when event is active
     * @param eventAddress The address of the event contract
     * @param newPrice The new price in payment token units
     */
    function setTicketPrice(address eventAddress, uint256 newPrice) external onlyOwner whenNotPaused {
        require(
            EventTicket(eventAddress).organizationContract() == address(this),
            NotEventOwner(eventAddress)
        );
        require(newPrice > 0, InvalidPrice(newPrice));
        EventTicket(eventAddress).setTicketPrice(newPrice);
    }

    /**
     * @notice Updates deadline for an event
     * @dev Only callable by owner when event is active
     */
    function setDeadline(address eventAddress, uint256 newDeadline) external onlyOwner whenNotPaused {
        require(
            EventTicket(eventAddress).organizationContract() == address(this),
            NotEventOwner(eventAddress)
        );
        require(newDeadline > block.timestamp, InvalidDeadline(newDeadline, block.timestamp));
        EventTicket(eventAddress).setDeadline(newDeadline);
    }

    /**
     * @notice Transfers ownership to a new address
     * @dev Only callable by platform contract
     */
    function transferOwnership(address newOwner) external onlyPlatform {
        require(newOwner != address(0), InvalidOwner(newOwner));
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner, block.timestamp);
    }

    /**
     * @notice Pauses organization operations
     * @dev Only callable by platform contract
     */
    function pause() external onlyPlatform {
        _pause();
    }

    /**
     * @notice Unpauses organization operations
     * @dev Only callable by platform contract
     */
    function unpause() external onlyPlatform {
        _unpause();
    }

    /**
     * @notice Withdraws tokens to the organization owner
     * @dev Only callable by owner
     * @param token The address of the token to withdraw
     */
    function withdrawTokens(address token) external onlyOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        bool success = tokenContract.transfer(owner, balance);
        require(success, TokenTransferFailed(token, address(this), owner, balance));
        
        emit TokensReceived(token, balance, block.timestamp);
    }

    /**
     * @notice Allows organization to receive token payments
     */
    receive() external payable {
        revert("Token payments only");
    }
}