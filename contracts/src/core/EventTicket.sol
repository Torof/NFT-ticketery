// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./TicketPlatform.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title EventTicket
 * @notice NFT contract for event tickets with token-based payments and resale functionality
 * @dev Implements ERC721 for tickets, uses platform's payment token for transactions
 */
contract EventTicket is ERC721, Pausable, Initializable {
    // Custom Errors for validation and access control
    error NotOrganization(address caller);
    error EventClosed();
    error DeadlinePassed(uint256 deadline, uint256 current);
    error SoldOut(uint256 maxSupply);
    error InsufficientAllowance(uint256 required, uint256 provided);
    error TokenTransferFailed(address token, address from, address to, uint256 amount);
    error NotTokenOwner(address caller, uint256 tokenId);
    error InvalidDeadline(uint256 deadline, uint256 current);
    error InvalidInitialization(string reason);
    error InvalidRecipient(address recipient);
    error InvalidPrice(uint256 price);
    
    // State variables
    address public organizationContract;
    address public platformContract;
    uint256 public deadline;
    uint256 public ticketPrice;
    uint256 public maxSupply;
    uint256 public currentSupply;
    bool public isClosed;
    string private baseTokenURI;
    
    // Events for subgraph indexing
    event TicketMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 price,
        uint256 platformFee,
        uint256 timestamp
    );
    
    event TicketResold(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 price,
        uint256 platformFee,
        uint256 timestamp
    );
    
    event EventStatusUpdated(
        bool indexed isClosed,
        uint256 timestamp
    );
    
    event TicketPriceUpdated(
        uint256 oldPrice,
        uint256 newPrice,
        uint256 timestamp
    );
    
    event DeadlineUpdated(
        uint256 oldDeadline,
        uint256 newDeadline,
        uint256 timestamp
    );

    modifier onlyOrganization() {
        require(msg.sender == organizationContract, NotOrganization(msg.sender));
        _;
    }

    /**
     * @dev Contract constructor that disables initialization for the implementation contract
     */
    constructor() ERC721("Event Ticket", "TICKET") {
        _disableInitializers();
    }

    /**
     * @notice Initializes a new event ticket contract
     * @dev Called by factory when creating new event instances
     */
    function initialize(
        address _organizationContract,
        string memory _eventURI,
        uint256 _ticketPrice,
        uint256 _deadline,
        uint256 _maxSupply,
        address _platformContract
    ) external initializer {
        require(_organizationContract != address(0), InvalidInitialization("Invalid organization"));
        require(_platformContract != address(0), InvalidInitialization("Invalid platform"));
        require(_deadline > block.timestamp, InvalidInitialization("Invalid deadline"));
        require(_maxSupply > 0, InvalidInitialization("Invalid supply"));
        require(_ticketPrice > 0, InvalidInitialization("Invalid price"));
        
        organizationContract = _organizationContract;
        ticketPrice = _ticketPrice;
        deadline = _deadline;
        maxSupply = _maxSupply;
        platformContract = _platformContract;
        baseTokenURI = _eventURI;
    }

    /**
     * @notice Mints a new ticket to the caller
     * @dev Handles token payments, platform fees, and minting in one transaction
     */
    function mint() external whenNotPaused {
        require(!isClosed, EventClosed());
        require(block.timestamp < deadline, DeadlinePassed(deadline, block.timestamp));
        require(currentSupply < maxSupply, SoldOut(maxSupply));
        
        uint256 tokenId = currentSupply++;
        
        // Get payment token and validate allowance
        IERC20 paymentToken = TicketPlatform(platformContract).paymentToken();
        uint256 allowance = paymentToken.allowance(msg.sender, address(this));
        require(allowance >= ticketPrice, InsufficientAllowance(ticketPrice, allowance));
        
        // Calculate and process platform fee
        uint256 platformFee = (ticketPrice * TicketPlatform(platformContract).platformFee()) / 10000;
        uint256 organizationPayment = ticketPrice - platformFee;
        
        // Transfer platform fee
        bool feeSuccess = paymentToken.transferFrom(msg.sender, platformContract, platformFee);
        require(feeSuccess, TokenTransferFailed(address(paymentToken), msg.sender, platformContract, platformFee));
        
        // Transfer payment to organization
        bool paymentSuccess = paymentToken.transferFrom(
            msg.sender, 
            organizationContract, 
            organizationPayment
        );
        require(
            paymentSuccess, 
            TokenTransferFailed(address(paymentToken), msg.sender, organizationContract, organizationPayment)
        );
        
        _safeMint(msg.sender, tokenId);
        
        emit TicketMinted(tokenId, msg.sender, ticketPrice, platformFee, block.timestamp);
    }

    /**
     * @notice Handles ticket resale between users
     * @dev Manages token transfers and platform fees for secondary market sales
     */
    function resell(uint256 tokenId, address to, uint256 price) external whenNotPaused {
        require(!isClosed, EventClosed());
        require(block.timestamp < deadline, DeadlinePassed(deadline, block.timestamp));
        require(ownerOf(tokenId) == msg.sender, NotTokenOwner(msg.sender, tokenId));
        require(to != address(0), InvalidRecipient(to));
        require(price > 0, InvalidPrice(price));
        
        IERC20 paymentToken = TicketPlatform(platformContract).paymentToken();
        
        // Validate buyer's token allowance
        uint256 allowance = paymentToken.allowance(to, address(this));
        require(allowance >= price, InsufficientAllowance(price, allowance));
        
        // Calculate and process platform fee
        uint256 platformFee = (price * TicketPlatform(platformContract).platformFee()) / 10000;
        uint256 sellerPayment = price - platformFee;
        
        // Transfer platform fee from buyer
        bool feeSuccess = paymentToken.transferFrom(to, platformContract, platformFee);
        require(feeSuccess, TokenTransferFailed(address(paymentToken), to, platformContract, platformFee));
        
        // Transfer payment to seller
        bool paymentSuccess = paymentToken.transferFrom(to, msg.sender, sellerPayment);
        require(paymentSuccess, TokenTransferFailed(address(paymentToken), to, msg.sender, sellerPayment));
        
        _transfer(msg.sender, to, tokenId);
        
        emit TicketResold(tokenId, msg.sender, to, price, platformFee, block.timestamp);
    }

    /**
     * @notice Hook that is called before any token transfer
     * @dev Ensures transfers only occur when event is active and before deadline
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(!isClosed, EventClosed());
        require(block.timestamp < deadline, DeadlinePassed(deadline, block.timestamp));
    }

    /**
     * @notice Updates ticket price
     * @dev Only callable by organization when event is active
     */
    function setTicketPrice(uint256 newPrice) external onlyOrganization {
        require(!isClosed, EventClosed());
        require(newPrice > 0, InvalidPrice(newPrice));
        
        uint256 oldPrice = ticketPrice;
        ticketPrice = newPrice;
        
        emit TicketPriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    /**
     * @notice Updates event deadline
     * @dev Only callable by organization when event is active
     */
    function setDeadline(uint256 newDeadline) external onlyOrganization {
        require(!isClosed, EventClosed());
        require(newDeadline > block.timestamp, InvalidDeadline(newDeadline, block.timestamp));
        
        uint256 oldDeadline = deadline;
        deadline = newDeadline;
        
        emit DeadlineUpdated(oldDeadline, newDeadline, block.timestamp);
    }

    /**
     * @notice Closes the event
     * @dev Prevents further minting and transfers
     */
    function close() external onlyOrganization {
        isClosed = true;
        emit EventStatusUpdated(true, block.timestamp);
    }

    /**
     * @notice Returns the base URI for token metadata
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @notice Validates if a ticket is valid for entry
     * @dev Checks if token exists and event is active
     */
    function validateTicket(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId) && !isClosed && block.timestamp < deadline;
    }
}