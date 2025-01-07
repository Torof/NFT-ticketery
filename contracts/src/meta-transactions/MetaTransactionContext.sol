// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../interfaces/IMetaTransactionContext.sol";

/**
 * @title MetaTransactionContext
 * @notice Simple context helper for meta-transactions
 */
abstract contract MetaTransactionContext is IMetaTransactionContext {
    function _msgSender() external view virtual override returns (address) {
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