# NFTickets

This platform revolutionizes event ticketing by leveraging blockchain technology while maintaining the simplicity of traditional ticketing systems. Our solution enables secure ticket ownership and verified resale markets through NFTs, all while keeping the underlying blockchain technology invisible to end users.

## Overview

The platform serves two distinct user groups through specialized interfaces. Event organizations can create and manage events, issue tickets, and track sales after completing KYC verification. End users can purchase, hold, and transfer tickets through familiar e-commerce interfaces, with all blockchain operations handled seamlessly by the platform.

We maintain fair market practices by implementing sophisticated controls that prevent ticket speculation while preserving true digital ownership. The platform ensures events remain accessible to all by maintaining reasonable pricing in both primary and secondary markets.

## Project Structure

The project is organized into two main components:

### Smart Contracts (`/contracts`)

Our smart contract architecture consists of four primary contracts:

- `EventFactory.sol`: Manages efficient deployment of new event contracts using the minimal proxy pattern
- `EventTicket.sol`: Implements the ERC-721 standard for NFT tickets with custom transfer restrictions
- `Organization.sol`: Handles organization-specific operations including event creation
- `TicketPlatform.sol`: The central contract managing platform operations and system configuration

### Frontend (`/src`)

A Next.js application providing user interfaces for both organizations and end users, leveraging modern web technologies for a seamless experience.

## Development Requirements

### Smart Contract Development

- Foundry
- Solidity ^0.8.27
- OpenZeppelin Contracts
- Forge Standard Library

### Frontend Development

- Node.js (v20+)
- Next.js 15.1.3
- React 19.0.0
- TypeScript 5
- Wagmi 2.14.6
- Viem 2.22.1
- TanStack Query 5.62.11

## Getting Started

### Smart Contract Development

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install dependencies:
```bash
cd contracts
forge install
```

3. Run tests:
```bash
forge test
```

4. Build contracts:
```bash
forge build
```

### Frontend Development

1. Install dependencies:
```bash
yarn install
```

2. Set up environment variables:
```bash
cp .env.example .env.local
```

3. Start the development server with Turbopack:
```bash
yarn dev
```

## Available Scripts

```bash
yarn dev          # Start development server with Turbopack
yarn build        # Create production build
yarn start        # Start production server
yarn lint         # Run ESLint
```

## Testing

### Smart Contract Testing

Execute tests using Foundry:

```bash
forge test                     # Run all tests
forge test --match-contract   # Run specific contract tests
forge coverage                # Generate coverage report
```

### Frontend Linting

```bash
yarn lint                     # Run ESLint
```

## Documentation

Comprehensive documentation is available in the following files:

- `guidelines.md`: Core project principles and architectural decisions
- `/docs/development-backlog.md`: Development roadmap and priorities
- `/docs/meta-transaction-specification.md`: Technical specification for gasless transactions

## Contributing

We welcome contributions that align with our project's vision of making event ticketing more accessible and secure. Please review our guidelines.md for architectural decisions and implementation standards before submitting pull requests.

## License

This project is licensed under the MIT License.

## Contact

[Contact Information]

---

For detailed technical information and development standards, please refer to our guidelines.md document.