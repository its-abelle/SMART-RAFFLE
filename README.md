# 🎟️ Provably Fair Smart Contract Lottery (Raffle)

A decentralized, automated, and provably fair lottery smart contract built with the [Foundry](https://book.getfoundry.sh/) framework. 

This project leverages **Chainlink VRF v2.5** (Verifiable Random Function) to guarantee tamper-proof randomness for winner selection, and **Chainlink Automation** (formerly Keepers) to automatically execute the lottery draw without any human intervention.

## 📖 Table of Contents
- [Architecture & Flow](#-architecture--flow)
- [Core Functionalities](#-core-functionalities)
- [Tech Stack](#-tech-stack)
- [Getting Started](#-getting-started)
- [Usage & Deployment](#-usage--deployment)
- [Testing & Debugging](#-testing--debugging)
- [Known Local Quirks](#-known-local-quirks)
- [License](#-license)

---

## 🏛 Architecture & Flow

The lifecycle of a single raffle round works in a completely decentralized manner:

1. **Users Enter:** Participants call the `enterRaffle()` function and pay the minimum entrance fee.
2. **Time Passes:** The contract tracks the time since the last draw.
3. **Automation Trigger:** Chainlink Automation nodes constantly simulate the `checkUpkeep()` function. Once the predefined time interval passes, `checkUpkeep()` returns true.
4. **Randomness Request:** Chainlink Automation automatically triggers the `performUpkeep()` function, which requests a secure random number from the Chainlink VRF Coordinator.



5. **Winner Selection:** The Chainlink VRF node calls back into the contract via `fulfillRandomWords()`, passing the random number. The contract calculates the winner using the modulo operator (`randomWord % players.length`), sends them the entire prize pool, and resets the raffle for the next round.



---

## ⚙️ Core Functionalities

### `enterRaffle()`
Allows users to buy a ticket. Reverts if:
* The user sends less than the required `i_entranceFee`.
* The raffle is currently in a `CALCULATING` state (meaning a draw is in progress).

### `checkUpkeep()`
A view function used by Chainlink Automation to determine if it's time to trigger a draw. It checks four conditions:
1. The specified time interval has passed.
2. The raffle is in an `OPEN` state.
3. The contract holds a positive ETH balance.
4. There is at least one player in the current round.

### `performUpkeep()`
The execution function called by Chainlink Automation. It:
* Validates that `checkUpkeep()` is true.
* Changes the raffle state from `OPEN` to `CALCULATING` (locking new entries).
* Emits a request to the Chainlink VRF Coordinator for a random word.

### `fulfillRandomWords()`
The callback function exclusively called by the Chainlink VRF Coordinator. It:
* Receives the cryptographically proven random number.
* Selects the winner from the `s_players` array.
* Resets the player array and timestamp.
* Opens the raffle back to the `OPEN` state.
* Transfers the ETH balance to the winner.

---

## 🛠️ Tech Stack

* **Smart Contracts:** Solidity (v0.8.19)
* **Development Framework:** Foundry (Forge, Anvil, Cast)
* **Oracles:** * Chainlink VRF v2.5 (Randomness)
  * Chainlink Automation (Smart Contract Keepers)
* **Scripting:** Makefile for streamlined deployment commands.

---

## 🚀 Getting Started

### Prerequisites
You need to have [Foundry](https://getfoundry.sh/) installed.

```bash
curl -L [https://foundry.paradigm.xyz](https://foundry.paradigm.xyz) | bash
foundryup

Installation
Clone the repository:

Bash
git clone https://github.com/its-abelle/SMART-RAFFLE
cd SMART-RAFFLE
Install the necessary dependencies (Chainlink Brownie Contracts, Solmate, OpenZeppelin, etc.):

Bash
forge install
Compile the contracts:

Bash
forge build
🚢 Usage & Deployment
This project uses HelperConfig.s.sol to automatically detect the network and deploy the correct mock contracts or use live addresses depending on your target chain.

Local Deployment (Anvil)
Deploying to a local Anvil node will automatically deploy the VRFCoordinatorV2_5Mock and LinkToken mocks, create a subscription, fund it, and add the Raffle contract as a consumer.

Bash
# Terminal 1: Start the local Anvil chain
anvil

# Terminal 2: Deploy using the Makefile
make deploy ARGS="--network anvil"
Testnet Deployment (Sepolia)
To deploy to a live testnet, you must configure your .env file with your SEPOLIA_RPC_URL, PRIVATE_KEY, and ETHERSCAN_API_KEY.

Ensure you have created and funded a Chainlink VRF v2.5 subscription on the Chainlink VRF Dashboard. Update the subscriptionId in HelperConfig.s.sol.

Bash
make deploy ARGS="--network sepolia"
🧪 Testing & Debugging
This repository features a robust test suite covering state transitions, custom errors, event emissions, and complex mock interactions.

To run all unit tests:

Bash
forge test
To run a specific test with maximum verbosity (Trace level 4) to debug state changes and internal calls:

Bash
forge test --mt testFulfillRandomWordsPicksAWinnerResetsTheRaffleAndSendsMoney -vvvv
To check test coverage:

Bash
forge coverage