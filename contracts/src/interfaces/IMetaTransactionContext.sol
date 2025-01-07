// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IMetaTransactionContext
 * @notice Interface for contracts that support meta-transactions
 */
interface IMetaTransactionContext {
    /**
     * @dev Returns the sender of the transaction (original signer for meta-transactions)
     */
    function _msgSender() view external returns (address);
}