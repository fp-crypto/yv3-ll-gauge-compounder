# Yearn V3 Liquid Locker (LL) Gauge Compounder Strategies

This repository contains implementations of Yearn V3 strategies for compounding rewards from various Liquid Locker (LL) gauge providers, including:

- Cove Finance
- 1UP (OneUp)
- StakeDAO

These strategies automatically compound rewards from LL gauges back into the underlying vault tokens, maximizing yield for users.

The repository is built on Yearn's V3 Tokenized Strategy framework using [Foundry](https://book.getfoundry.sh/).

## How to start

### Requirements

- First you will need to install [Foundry](https://book.getfoundry.sh/getting-started/installation).
NOTE: If you are on a windows machine it is recommended to use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)
- Install [Node.js](https://nodejs.org/en/download/package-manager/)

### Clone this repository

```sh
git clone --recursive https://github.com/fp-crypto/yv3-ll-gauge-compounder

cd tokenized-strategy-foundry-mix

yarn
```

### Set your environment Variables

Use the `.env.example` template to create a `.env` file and store the environement variables. You will need to populate the `RPC_URL` for the desired network(s). RPC url can be obtained from various providers, including [Ankr](https://www.ankr.com/rpc/) (no sign-up required) and [Infura](https://infura.io/).

Use .env file

1. Make a copy of `.env.example`
2. Add the value for `ETH_RPC_URL` and other example vars
     NOTE: If you set up a global environment variable, that will take precedence.

### Build the project

```sh
make build
```

Run tests

```sh
make test
```

## Repository Structure

The repository is organized as follows:

- `src/`: Contains the core strategy implementations
  - `BaseLLGaugeCompounderStrategy.sol`: Abstract base contract for all LL gauge compounder strategies
  - `CoveCompounderStrategy.sol`: Implementation for Cove Finance gauges
  - `OneUpCompounderStrategy.sol`: Implementation for 1UP gauges
  - `StakeDaoCompounderStrategy.sol`: Implementation for StakeDAO gauges
  - `factories/`: Contains factory contracts for deploying strategies
    - `BaseLLGaugeCompounderStrategy.sol`: Abstract base factory
    - `LLGaugeCompounderStrategiesFactory.sol`: Factory for deploying all three strategy types

For a complete guide to understanding Yearn's Tokenized Strategy framework, please visit: https://docs.yearn.fi/developers/v3/strategy_writing_guide

NOTE: Compiler defaults to 8.23 but it can be adjusted in the foundry toml.

## How It Works

These strategies work by:

1. Accepting deposits of Yearn vault tokens
2. Staking these tokens in the corresponding LL gauge (Cove, 1UP, or StakeDAO)
3. Periodically harvesting rewards (typically dYFI or other tokens)
4. Swapping these rewards back to the underlying asset
5. Depositing the compounded assets back into the Yearn vault
6. Restaking the received vault tokens in the gauge

This cycle creates a compounding effect that maximizes returns for users while maintaining the security and liquidity benefits of the underlying Yearn vault.

## Testing

The test suite covers all three strategy implementations and their factory contracts. Due to the nature of the BaseStrategy utilizing an external contract for the majority of its logic, testing uses the pre-built [IStrategyInterface](https://github.com/yearn/tokenized-strategy-foundry-mix/blob/master/src/interfaces/IStrategyInterface.sol) to cast any deployed strategy for testing.

Example:

```solidity
CoveCompounderStrategy _strategy = new CoveCompounderStrategy(asset, name);
IStrategyInterface strategy = IStrategyInterface(address(_strategy));

Tests run in fork environment, you need to complete the full installation and setup to be able to run these commands.

```sh
make test
```

Run tests with traces (very useful)

```sh
make trace
```

Run specific test contract (e.g. `test/StrategyOperation.t.sol`)

```sh
make test-contract contract=StrategyOperationsTest
```

Run specific test contract with traces (e.g. `test/StrategyOperation.t.sol`)

```sh
make trace-contract contract=StrategyOperationsTest
```

See here for some tips on testing [`Testing Tips`](https://book.getfoundry.sh/forge/tests.html)

When testing on chains other than mainnet you will need to make sure a valid `CHAIN_RPC_URL` for that chain is set in your .env. You will then need to simply adjust the variable that RPC_URL is set to in the Makefile to match your chain.

To update to a new API version of the TokenizeStrategy you will need to simply remove and reinstall the dependency.

### Test Coverage

Run the following command to generate a test coverage:

```sh
make coverage
```

To generate test coverage report in HTML, you need to have installed [`lcov`](https://github.com/linux-test-project/lcov) and run:

```sh
make coverage-html
```

The generated report will be in `coverage-report/index.html`.

### Deployment

#### Contract Verification

Once the Strategy is fully deployed and verified, you will need to verify the TokenizedStrategy functions. To do this, navigate to the /#code page on Etherscan.

1. Click on the `More Options` drop-down menu
2. Click "is this a proxy?"
3. Click the "Verify" button
4. Click "Save"

This should add all of the external `TokenizedStrategy` functions to the contract interface on Etherscan.

## CI

This repo uses [GitHub Actions](.github/workflows) for CI. There are three workflows: lint, test and slither for static analysis.

To enable test workflow you need to add the `ETH_RPC_URL` secret to your repo. For more info see [GitHub Actions docs](https://docs.github.com/en/codespaces/managing-codespaces-for-your-organization/managing-encrypted-secrets-for-your-repository-and-organization-for-github-codespaces#adding-secrets-for-a-repository).

If the slither finds some issues that you want to suppress, before the issue add comment: `//slither-disable-next-line DETECTOR_NAME`. For more info about detectors see [Slither docs](https://github.com/crytic/slither/wiki/Detector-Documentation).

### Coverage

If you want to use [`coverage.yml`](.github/workflows/coverage.yml) workflow on other chains than mainnet, you need to add the additional `CHAIN_RPC_URL` secret.

Coverage workflow will generate coverage summary and attach it to PR as a comment. To enable this feature you need to add the [`GH_TOKEN`](.github/workflows/coverage.yml#L53) secret to your Github repo. Token must have permission to "Read and Write access to pull requests". To generate token go to [Github settings page](https://github.com/settings/tokens?type=beta). For more info see [GitHub Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).
