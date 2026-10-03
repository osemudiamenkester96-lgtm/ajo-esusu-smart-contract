# Ajo / Esusu Smart Contract

A blockchain-based rotating savings system (Ajo/Esusu) built with **Solidity, Foundry, and ERC-20 tokens**.

The smart contract allows a fixed group of members to contribute an agreed amount during each cycle. Once every member has contributed, the entire cycle's contribution pool is automatically paid to the member whose turn it is to receive the payout.

## Overview

Ajo, also known as Esusu in some parts of Africa, is a traditional rotating savings system where a group of people contribute a fixed amount regularly and members receive the accumulated contribution in turns.

This project brings that concept on-chain using an Ethereum-compatible smart contract.

The system is designed around:

* Fixed membership
* Ordered payout rotation
* ERC-20 token contributions
* Automatic payouts
* Contribution deadlines
* Cycle cancellation
* Contribution refunds
* Access control
* Reentrancy protection

## How It Works

1. The organizer deploys the Ajo contract with:

   * ERC-20 token address
   * Contribution amount
   * Cycle duration
   * Maximum number of members

2. Members join the pool.

3. The order in which members join determines their payout position.

4. The organizer starts the pool.

5. Each member contributes once during every cycle.

6. When all members have contributed:

   * The contributions are pooled.
   * The current recipient receives the entire pool.
   * The next cycle begins automatically.

7. The process continues until every member has received a payout.

### Example

With **3 members** contributing **100 mUSDC** per cycle:

| Cycle | Recipient | Total Payout |
| ----- | --------- | -----------: |
| 1     | Member 1  |    300 mUSDC |
| 2     | Member 2  |    300 mUSDC |
| 3     | Member 3  |    300 mUSDC |

Each member contributes 100 mUSDC per cycle and receives 300 mUSDC when it is their turn.

## Features

### Member Management

* Members can join before the pool starts.
* Join order determines payout order.
* Duplicate membership is prevented.
* Membership is limited by the configured maximum.

### Contributions

* Members contribute ERC-20 tokens.
* Each member can contribute only once per cycle.
* Contributions require ERC-20 approval.
* Contributions are rejected after the cycle deadline.

### Automatic Payouts

When all members contribute:

```text
Contribution Amount × Number of Members = Payout
```

The payout is automatically transferred to the current recipient.

### Cycle Management

* Cycles advance automatically after successful payouts.
* The final cycle closes the pool.
* The current recipient can be queried on-chain.

### Cancellation & Refunds

If a cycle remains incomplete after its contribution window expires, the organizer can cancel the cycle.

Members who contributed during that cycle can then claim their contribution back.

### Security

The contract includes:

* Custom Solidity errors
* Organizer-only administrative functions
* Reentrancy protection
* ERC-20 transfer failure checks
* State validation
* Contribution tracking

## Project Structure

```text
ajo-chain/
├── .github/
│   └── workflows/
│       └── test.yml
├── lib/
│   ├── forge-std/
│   └── openzeppelin-contracts/
├── script/
│   ├── Ajo.s.sol
│   ├── DeployMockUSDC.s.sol
│   └── MintMockUSDC.s.sol
├── src/
│   ├── Ajo.sol
│   └── MockUSDC.sol
├── test/
│   └── Ajo.t.sol
├── foundry.toml
├── foundry.lock
└── README.md
```

## Technology Stack

* **Solidity:** ^0.8.30
* **Foundry:** Development, testing and deployment
* **OpenZeppelin:** ERC-20 implementation and interfaces
* **Ethereum / EVM:** Smart-contract execution environment
* **ERC-20:** Contribution token standard
* **Sepolia:** Testnet deployment

## Testing

The project currently contains **18 automated tests** covering deployment, membership, contributions, payouts, cycle progression, access control, cancellation and refunds.

Run the test suite with:

```bash
forge test -vv
```

Expected result:

```text
18 passed
0 failed
0 skipped
```

## Local Development

Clone the repository:

```bash
git clone https://github.com/osemudiamenkester96-lgtm/ajo-esusu-smart-contract.git
cd ajo-esusu-smart-contract
```

Initialize the Git submodules:

```bash
git submodule update --init --recursive
```

Build the project:

```bash
forge build
```

Run tests:

```bash
forge test
```

Format the contracts:

```bash
forge fmt
```

## Deployment

The project includes scripts for deploying the Ajo contract and the mock ERC-20 token.

### Deploy Mock USDC

```bash
forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### Mint Mock USDC

```bash
forge script script/MintMockUSDC.s.sol:MintMockUSDC \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### Deploy Ajo

```bash
forge script script/Ajo.s.sol:AjoScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

Deployment configuration is stored in environment variables and should **never be committed to Git**.

## Sepolia Deployment

The Ajo system has been deployed and tested on the **Sepolia testnet**.

### Mock USDC

```text
0x095B567D5cD521B2538B1Bb8f8051ADC4029cc45
```

### Ajo Contract

```text
0x46F404257ef01FC7EF7d245ED56Ff2deFd9Ee5b6
```

The deployed Ajo contract was configured with:

```text
Contribution: 1 mUSDC
Cycle duration: 1 hour
Maximum members: 3
```

The complete three-cycle lifecycle was successfully demonstrated on Sepolia, including:

* Member joining
* Contributions
* Automatic payouts
* Cycle progression
* Final pool completion

## Smart Contract Design

The payout order is determined by member join order.

For example:

```text
Member 1 → Cycle 1 recipient
Member 2 → Cycle 2 recipient
Member 3 → Cycle 3 recipient
```

The contract tracks:

```solidity
currentCycle
memberCount
contributionsThisCycle
cycleStartedAt
started
closed
cycleCancelled
```

It also tracks individual member participation for each cycle.

## Security Considerations

This project is an educational and portfolio implementation and has **not been professionally audited**.

Important considerations for production deployment would include:

* Professional smart-contract audit
* Stronger token validation
* Production-grade access control
* Emergency administration mechanisms
* Handling of malicious or non-standard ERC-20 tokens
* More sophisticated dispute and recovery mechanisms
* Formal security testing
* Economic and game-theoretic analysis

The included `MockUSDC` token intentionally exposes a public `mint()` function for testnet demonstrations. It should **not** be treated as a production stablecoin.

## Future Improvements

Potential future versions could include:

* Dynamic membership
* Multiple savings pools
* Stablecoin integration
* On-chain reputation
* Pool invitations
* Member voting
* Dispute resolution
* Frontend dashboard
* Wallet connection
* Transaction history
* Notifications
* Production-grade access control
* Deployment to an L2 network

## Author

**Kester Usifoh**

Built as a hands-on Solidity and blockchain development capstone project.

## License

MIT

