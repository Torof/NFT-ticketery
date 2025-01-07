// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IMetaTransactionRelay
 * @notice Interface for the meta-transaction relay contract
 */
interface IMetaTransactionRelay {
    /**
     * @dev Emitted when a meta-transaction is executed
     */
    event MetaTransactionExecuted(
        address indexed from,
        address indexed to,
        bytes data,
        bool success,
        uint256 nonce
    );

    /**
     * @dev Custom errors
     */
    error InvalidSignature(address expected, address actual);
    error TransactionExpired(uint256 deadline, uint256 timestamp);
    error ExecutionFailed(address target, bytes data);

    /**
     * @notice Executes a meta-transaction
     * @param from Original transaction signer
     * @param to Target contract
     * @param data Encoded function call data
     * @param deadline Timestamp after which the transaction is invalid
     * @param signature EIP-712 signature
     * @return success Whether the execution was successful
     * @return result Return data from the call
     */
    function executeMetaTransaction(
        address from,
        address to,
        bytes calldata data,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool success, bytes memory result);

    /**
     * @notice Gets the current nonce for a user
     * @param user Address to query
     * @return Current nonce
     */
    function getNonce(address user) external view returns (uint256);
}