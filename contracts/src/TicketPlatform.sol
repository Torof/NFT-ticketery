// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Organization.sol";
import "./EventTicket.sol";
import "./EventFactory.sol";
import "./IERC20.sol";

/**
 * @title TicketPlatform
 * @notice Central contract managing the ticketing platform's core functionality
 * @dev Implements token-based payments and custom errors with require statements
 */
contract TicketPlatform is Ownable, Pausable, ReentrancyGuard {
    // Custom Errors for clear, gas-efficient error handling
    error NotAuthorized(address caller);
    error AlreadyHasOrganization(address owner);
    error InvalidAddress(address addr);
    error InvalidToken(address token);
    error FeeExceedsMaximum(uint256 providedFee, uint256 maxFee);
    error NotAnOrganization(address caller);
    error EventNotActive(address eventAddress);
    error EventNotFound(address eventAddress);
    error InvalidOwnershipTransfer(address currentOwner, address newOwner);
    
    // Core state mappings for O(1) lookups
    mapping(address => bool) public isOrganization;           
    mapping(address => address) public organizationsByOwner;  
    mapping(address => address) public organizationOwners;    
    mapping(address => bool) public isActiveEvent;           
    mapping(address => bool) public isPastEvent;             
    mapping(address => bool) public allowedOrganizers;       

    // Platform configuration
    uint256 public platformFee;       // Fee in basis points (100% = 10000)
    EventFactory public eventFactory; // Factory for creating new event contracts
    IERC20 public paymentToken;      // Token used for all platform payments

    // Events for subgraph indexing
    event OrganizationCreated(
        address indexed organizationAddress,
        address indexed owner,
        uint256 timestamp
    );
    
    event OrganizationOwnershipTransferred(
        address indexed organizationAddress,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );
    
    event OrganizerStatusChanged(
        address indexed organizer,
        bool indexed isAllowed,
        uint256 timestamp
    );
    
    event OrganizationStatusChanged(
        address indexed organizationAddress,
        bool indexed isActive,
        uint256 timestamp
    );
    
    event EventRegistered(
        address indexed eventAddress,
        address indexed organizationAddress,
        string eventURI,
        uint256 ticketPrice,
        uint256 maxSupply,
        uint256 deadline,
        uint256 timestamp
    );
    
    event EventStatusChanged(
        address indexed eventAddress,
        bool indexed isActive,
        uint256 timestamp
    );
    
    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event PaymentTokenUpdated(
        address indexed oldToken,
        address indexed newToken,
        uint256 timestamp
    );

    constructor(
        uint256 _initialFee, 
        address _eventImplementation,
        address _paymentToken
    ) {
        require(_paymentToken != address(0), InvalidToken(_paymentToken));
        platformFee = _initialFee;
        eventFactory = new EventFactory(_eventImplementation);
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @notice Creates a new organization
     * @dev Only allowed organizers can create organizations, and only one per address
     */
    function createOrganization() external nonReentrant whenNotPaused returns (address) {
        require(allowedOrganizers[msg.sender], NotAuthorized(msg.sender));
        require(organizationsByOwner[msg.sender] == address(0), AlreadyHasOrganization(msg.sender));
        
        Organization newOrg = new Organization(msg.sender, address(this));
        
        isOrganization[address(newOrg)] = true;
        organizationsByOwner[msg.sender] = address(newOrg);
        organizationOwners[address(newOrg)] = msg.sender;
        
        emit OrganizationCreated(
            address(newOrg),
            msg.sender,
            block.timestamp
        );
        
        return address(newOrg);
    }

    /**
     * @notice Transfers organization ownership to a new address
     * @dev Updates all relevant mappings and the organization contract itself
     */
    function transferOrganizationOwnership(address newOwner) external whenNotPaused {
        require(newOwner != address(0), InvalidAddress(newOwner));
        require(organizationsByOwner[newOwner] == address(0), AlreadyHasOrganization(newOwner));
        
        address orgAddress = organizationsByOwner[msg.sender];
        require(orgAddress != address(0), InvalidOwnershipTransfer(msg.sender, newOwner));
        
        organizationsByOwner[msg.sender] = address(0);
        organizationsByOwner[newOwner] = orgAddress;
        organizationOwners[orgAddress] = newOwner;
        
        Organization(orgAddress).transferOwnership(newOwner);
        
        emit OrganizationOwnershipTransferred(
            orgAddress,
            msg.sender,
            newOwner,
            block.timestamp
        );
    }

    /**
     * @notice Updates the payment token address
     * @dev Only callable by owner, verifies the new token address
     */
    function updatePaymentToken(address newToken) external onlyOwner {
        require(newToken != address(0), InvalidToken(newToken));
        address oldToken = address(paymentToken);
        paymentToken = IERC20(newToken);
        emit PaymentTokenUpdated(oldToken, newToken, block.timestamp);
    }

    /**
     * @notice Updates organizer's permission to create organizations
     */
    function setOrganizerStatus(address organizer, bool status) external onlyOwner {
        require(organizer != address(0), InvalidAddress(organizer));
        allowedOrganizers[organizer] = status;
        emit OrganizerStatusChanged(organizer, status, block.timestamp);
    }

    /**
     * @notice Suspends or reactivates an organization
     */
    function setOrganizationStatus(address organizationAddress, bool isActive) external onlyOwner {
        require(isOrganization[organizationAddress], NotAnOrganization(organizationAddress));
        
        if (!isActive) {
            Organization(organizationAddress).pause();
        } else {
            Organization(organizationAddress).unpause();
        }
        
        emit OrganizationStatusChanged(
            organizationAddress,
            isActive,
            block.timestamp
        );
    }

    /**
     * @notice Updates platform fee
     * @dev Fee is in basis points (100% = 10000)
     */
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10000, FeeExceedsMaximum(newFee, 10000));
        uint256 oldFee = platformFee;
        platformFee = newFee;
        
        emit PlatformFeeUpdated(oldFee, newFee, block.timestamp);
    }

    /**
     * @notice Registers a new event
     * @dev Called by Organization contracts when creating events
     */
    function registerEvent(
        address eventAddress,
        string memory eventURI,
        uint256 ticketPrice,
        uint256 maxSupply,
        uint256 deadline
    ) external whenNotPaused {
        require(isOrganization[msg.sender], NotAnOrganization(msg.sender));
        isActiveEvent[eventAddress] = true;
        
        emit EventRegistered(
            eventAddress,
            msg.sender,
            eventURI,
            ticketPrice,
            maxSupply,
            deadline,
            block.timestamp
        );
    }

    /**
     * @notice Marks an event as closed
     * @dev Updates event status and emits event for indexing
     */
    function markEventAsClosed(address eventAddress) external whenNotPaused {
        require(isOrganization[msg.sender], NotAnOrganization(msg.sender));
        require(isActiveEvent[eventAddress], EventNotActive(eventAddress));
        
        isActiveEvent[eventAddress] = false;
        isPastEvent[eventAddress] = true;
        
        emit EventStatusChanged(eventAddress, false, block.timestamp);
    }

    // View Functions
    function hasOrganization(address owner) public view returns (bool) {
        return organizationsByOwner[owner] != address(0);
    }

    function getOrganizationAddress(address owner) external view returns (address) {
        return organizationsByOwner[owner];
    }

    function getOrganizationOwner(address organization) external view returns (address) {
        return organizationOwners[organization];
    }

    function isEventOrganizer(address org, address eventAddress) public view returns (bool) {
        return EventTicket(eventAddress).organizationContract() == org;
    }
}