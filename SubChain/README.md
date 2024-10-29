# CreatorPass Subscription Token Contract

## Overview
The `CreatorPass` Subscription Token Contract is a Clarity smart contract designed to facilitate subscription-based NFTs on the Stacks blockchain. This contract provides functionality for users to subscribe to different membership tiers by minting tokens, paying subscription fees, and enabling or disabling features depending on the subscription status. Each token represents a unique subscription to a tiered service, which can be paused, transferred, and administered with robust security controls.

## Contract Version
- **Version**: 1.0.0

## Features
- **Subscription Management**: Allows users to subscribe to different tiers, each with unique attributes.
- **Reentrancy Guard**: Prevents reentrancy attacks by enforcing atomic operations on sensitive functions.
- **NFT Trait Implementation**: Complies with SIP-009 to handle NFTs, enabling token tracking, transfers, and ownership.
- **Tier Pricing System**: Supports multiple subscription tiers with unique pricing and feature descriptions.
- **Administrative Control**: Allows designated administrators to manage subscription tiers, pause the contract, and add/remove administrators.
- **Security**: Incorporates access control, reentrancy checks, and the ability to pause the contract in case of emergency.

## Table of Contents
1. [Traits and Constants](#traits-and-constants)
2. [Data Variables](#data-variables)
3. [Core Functions](#core-functions)
4. [Security Features](#security-features)
5. [Practical Use Case](#practical-use-case)
6. [Installation and Usage](#installation-and-usage)
7. [Example Test Cases](#example-test-cases)
8. [Future Enhancements](#future-enhancements)

---

### Traits and Constants

#### Traits
The contract defines two primary traits for interacting with the token and fungible tokens (FTs) used for payments:
1. **sip009-nft-trait**: Implements standard NFT functions including `get-owner`, `transfer`, `get-token-uri`, and `get-last-token-id`.
2. **ft-trait**: Implements functions for fungible tokens, specifically `transfer` and `get-balance`.

#### Constants
Key constants include:
- **CONTRACT-OWNER**: Defines the contract owner’s principal.
- **Error Codes**:
  - `ERR-NOT-AUTHORIZED`: Unauthorized action.
  - `ERR-PAUSED`: Contract paused.
  - `ERR-INVALID-TIER`: Tier not recognized.
  - `ERR-TOKEN-NOT-FOUND`: Token does not exist.
  - `ERR-REENTRANCY`: Reentrancy protection triggered.

### Data Variables

1. **contract-paused**: Boolean variable indicating if the contract is paused.
2. **total-supply**: Tracks the total number of tokens minted.
3. **last-token-id**: Stores the ID of the last minted token.
4. **reentrancy-guard**: Used to enforce atomic operations.

### Core Functions

#### Mint Subscription
- **Function**: `mint-subscription (tier uint) (payment-token <ft-trait>)`
- **Description**: Mints a new subscription token for a specified tier. The user must pay the required fee using a compatible fungible token. Upon successful payment, a new NFT token representing the subscription is created.
- **Usage**:
  - **Arguments**:
    - `tier`: The subscription tier.
    - `payment-token`: The fungible token used for payment.
  - **Returns**: Token ID of the newly minted subscription.

#### Pause and Unpause Contract
- **Functions**: `pause-contract`, `unpause-contract`
- **Description**: Admin functions to pause or unpause the contract. When paused, most functions become inaccessible.
- **Usage**:
  - Pausing can be done only by the contract owner or authorized administrators.

#### Transfer Token
- **Function**: `transfer (token-id uint) (sender principal) (recipient principal)`
- **Description**: Transfers the subscription NFT from one principal to another.
- **Usage**:
  - **Arguments**:
    - `token-id`: The ID of the subscription token.
    - `sender`: The principal transferring the token.
    - `recipient`: The principal receiving the token.

### Security Features

1. **Reentrancy Guard**: Uses `begin-atomic` and `end-atomic` functions to enforce atomicity in critical functions and prevent reentrancy attacks.
2. **Access Control**: Functions are restricted to the contract owner or authorized administrators.
3. **Pause Functionality**: Allows contract administrators to pause the contract in emergencies, preventing further minting, transfers, or updates until resolved.

---

### Practical Use Case

**Scenario**: A digital content platform wants to offer subscription-based access to exclusive content through NFT-based memberships. Each subscription tier has different access levels and perks. The platform wants a blockchain-based system to ensure decentralized ownership and easy transfer of subscription tokens.

**Solution with CreatorPass**:
1. **Platform Setup**:
   - The platform deploys the `CreatorPass Subscription Token Contract` and defines various subscription tiers within it.
   - Each tier has a specific price and feature set defined in `tier-prices`.

2. **User Subscription**:
   - A user wishing to subscribe to the platform purchases a membership by interacting with the `mint-subscription` function.
   - They specify their desired tier and pay the required amount in a supported fungible token.
   - Upon successful payment, the contract mints a new subscription token (NFT) that represents the user’s membership level and is bound to their principal.

3. **Subscription Management**:
   - The platform’s administrators can pause or unpause the contract, manage subscription tiers, or revoke memberships if needed.
   - Users can transfer their subscription tokens to other users, allowing flexible ownership.

4. **Access Control**:
   - The platform verifies ownership through the `get-owner` function, granting access to exclusive content based on the user's subscription token.

---

### Installation and Usage

1. **Clone Repository**:
   ```bash
   git clone https://github.com/your-org/creatorpass-subscription.git
   cd creatorpass-subscription
   ```

2. **Deploy Contract**:
   - Using Clarity and the Stacks CLI, deploy the contract to a testnet or mainnet.

3. **Mint Subscription**:
   - Users can mint a subscription by calling `mint-subscription` and paying with the specified fungible token.

4. **Manage Subscriptions**:
   - Platform administrators can manage subscriptions through functions like `pause-contract`, `set-administrator`, etc.

5. **Testing**:
   - Run test cases to ensure all functionalities work as expected.

### Example Test Cases

Here are some sample test cases you can run using Clarinet:

1. **Mint Subscription Test**:
   - Verify that calling `mint-subscription` with the correct parameters successfully mints a token.

2. **Pause and Unpause Contract Test**:
   - Test that pausing the contract prevents minting and that unpausing allows minting again.

3. **Transfer Token Test**:
   - Confirm that the `transfer` function works correctly, transferring the ownership of the token from one user to another.

### Future Enhancements

- **Renewable Subscriptions**: Add functionality for users to renew their subscriptions before expiration.
- **Multi-Tiered Access Control**: Enable advanced features for different subscription tiers directly within the contract.
- **Integration with Front-End UI**: Provide a user-friendly interface for users to interact with their subscriptions and view membership details.