// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @title MetaTransactionContext
 * @notice Abstract contract providing context helpers for meta-transactions
 * @dev Implements internal _msgSender to support gasless transactions
 */
abstract contract MetaTransactionContext is Context {
    /**
     * @dev Returns the sender of the transaction (original signer for meta-transactions)
     */
    function _msgSender() internal view virtual override returns (address) {
        if (msg.data.length >= 20) {
            assembly {
                let length := calldatasize()
                if iszero(lt(length, 20)) {
                    let startByte := sub(length, 20)
                    calldatacopy(0, startByte, 20)
                    return(0, 20)
                }
            }
        }
        return msg.sender;
    }
}