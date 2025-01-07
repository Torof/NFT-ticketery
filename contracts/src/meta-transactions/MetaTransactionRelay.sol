// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMetaTransactionRelay.sol";

/**
 * @title MetaTransactionRelay
 * @notice Simple relay for gasless transactions
 */
contract MetaTransactionRelay is IMetaTransactionRelay, ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    bytes32 private immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor() Ownable(msg.sender) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NFTickets Meta Transaction Relay"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function executeMetaTransaction(
        address from,
        address to,
        bytes calldata data,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant override returns (bool success, bytes memory result) {
        // Validate deadline
        if (block.timestamp > deadline) {
            revert TransactionExpired(deadline, block.timestamp);
        }

        // Validate signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("MetaTransaction(address from,address to,uint256 nonce,bytes data,uint256 deadline)"),
                from,
                to,
                nonces[from],
                keccak256(data),
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                structHash
            )
        );

        address signer = digest.recover(signature);
        if (signer != from) {
            revert InvalidSignature(from, signer);
        }

        // Increment nonce
        nonces[from]++;

        // Execute transaction
        (success, result) = to.call(abi.encodePacked(data, from));
        if (!success) {
            revert ExecutionFailed(to, data);
        }

        emit MetaTransactionExecuted(from, to, data, success, nonces[from] - 1);
    }

    function getNonce(address user) external view override returns (uint256) {
        return nonces[user];
    }
}