// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../meta-transactions/MetaTransactionContext.sol";
import "./EventTicket.sol";
import "./TicketPlatform.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Organization
 * @notice Contract managing organization operations with gasless transaction support
 * @dev Implements MetaTransactionContext for gasless operations
 */
contract Organization is Pausable, MetaTransactionContext {
    // Custom Errors
    error NotOwner(address sender);
    error NotPlatform(address sender);
    error InvalidOwner(address owner);
    error InvalidPlatform(address platform);
    error InvalidDeadline(uint256 deadline, uint256 current);
    error InvalidSupply(uint256 supply);
    error InvalidPrice(uint256 price);
    error NotEventOwner(address eventAddress);
    error EventAlreadyClosed(address eventAddress);
    error NoTokensToWithdraw(address token);
    error TokenTransferFailed(address token, address from, address to, uint256 amount);
    
    // State variables
    address public owner;
    address public immutable platformContract;
    string public bannerIPFS;
    
    // Events
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
        require(_msgSender() == owner, NotOwner(_msgSender()));
        _;
    }
    
    modifier onlyPlatform() {
        require(_msgSender() == platformContract, NotPlatform(_msgSender()));
        _;
    }

    /**
     * @dev Override _msgSender to handle meta-transactions
     */
    function _msgSender() internal view virtual override(Context, MetaTransactionContext) returns (address) {
        return MetaTransactionContext._msgSender();
    }

    constructor(address _owner, address _platformContract) {
        require(_owner != address(0), InvalidOwner(_owner));
        require(_platformContract != address(0), InvalidPlatform(_platformContract));
        owner = _owner;
        platformContract = _platformContract;
    }

    /**
     * @notice Updates organization's banner IPFS hash with gasless transaction support
     */
    function updateBanner(string memory newBannerHash) external onlyOwner whenNotPaused {
        bannerIPFS = newBannerHash;
        emit BannerUpdated(newBannerHash, block.timestamp);
    }

    /**
     * @notice Creates a new event with gasless transaction support
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
     * @notice Closes an event with gasless transaction support
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
     * @notice Updates ticket price with gasless transaction support
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
     * @notice Updates deadline with gasless transaction support
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
     * @notice Transfers ownership with gasless transaction support
     * @dev Only callable by platform contract
     */
    function transferOwnership(address newOwner) external onlyPlatform {
        require(newOwner != address(0), InvalidOwner(newOwner));
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner, block.timestamp);
    }

    /**
     * @notice Withdraws tokens with gasless transaction support
     */
    function withdrawTokens(address token) external onlyOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, NoTokensToWithdraw(token));
        
        bool success = tokenContract.transfer(owner, balance);
        require(success, TokenTransferFailed(token, address(this), owner, balance));
        
        emit TokensReceived(token, balance, block.timestamp);
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
     * @notice Allows organization to receive token payments
     */
    receive() external payable {
        revert("Token payments only");
    }
}