// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./EventTicket.sol";

/**
 * @title EventFactory
 * @notice Factory contract for creating new event contracts using minimal proxies
 * @dev Implements EIP-1167 minimal proxy pattern for gas-efficient contract deployment
 * 
 * The factory keeps a reference to a master implementation of the EventTicket contract
 * and creates cheap clones of it for each new event. This significantly reduces gas costs
 * compared to deploying a full contract for each event.
 */
contract EventFactory {
    // Custom Errors for validation
    error InvalidImplementation(address implementation);
    error InvalidOrganization(address organization);
    error InvalidPlatform(address platform);
    error InvalidDeadline(uint256 deadline, uint256 current);
    error InvalidSupply(uint256 supply);
    error InvalidPrice(uint256 price);

    // The address of the implementation contract to clone
    address public immutable implementationContract;
    
    // Events for subgraph indexing and tracking contract creation
    event EventContractCreated(
        address indexed eventAddress,
        address indexed organizationAddress,
        string eventURI,
        uint256 ticketPrice,
        uint256 maxSupply,
        uint256 deadline,
        uint256 timestamp
    );

    /**
     * @notice Initializes the factory with an implementation contract
     * @dev The implementation contract will be used as a template for all events
     * @param _implementation Address of the implementation contract
     */
    constructor(address _implementation) {
        if (_implementation == address(0)) {
            revert InvalidImplementation(_implementation);
        }
        implementationContract = _implementation;
    }

    /**
     * @notice Creates a new event contract using minimal proxy pattern
     * @dev Clones the implementation contract and initializes it with provided parameters
     * 
     * @param organizationContract Address of the organization creating the event
     * @param eventURI IPFS URI containing event metadata
     * @param ticketPrice Price per ticket in payment token units
     * @param deadline Timestamp after which tickets cannot be transferred
     * @param maxSupply Maximum number of tickets that can be minted
     * @param platformContract Address of the platform contract
     * 
     * @return address Address of the newly created event contract
     */
    function createEvent(
        address organizationContract,
        string memory eventURI,
        uint256 ticketPrice,
        uint256 deadline,
        uint256 maxSupply,
        address platformContract
    ) external returns (address) {
        // Input validation
        if (organizationContract == address(0)) {
            revert InvalidOrganization(organizationContract);
        }
        if (platformContract == address(0)) {
            revert InvalidPlatform(platformContract);
        }
        if (deadline <= block.timestamp) {
            revert InvalidDeadline(deadline, block.timestamp);
        }
        if (maxSupply == 0) {
            revert InvalidSupply(maxSupply);
        }
        if (ticketPrice == 0) {
            revert InvalidPrice(ticketPrice);
        }

        // Clone the implementation contract using minimal proxy pattern
        address clone = Clones.clone(implementationContract);
        
        // Initialize the cloned contract with the provided parameters
        EventTicket(clone).initialize(
            organizationContract,
            eventURI,
            ticketPrice,
            deadline,
            maxSupply,
            platformContract
        );
        
        // Emit event for tracking and indexing
        emit EventContractCreated(
            clone,
            organizationContract,
            eventURI,
            ticketPrice,
            maxSupply,
            deadline,
            block.timestamp
        );
        
        return clone;
    }
}