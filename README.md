## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Unit Tests
forge test --match-contract ReputationRegistry -vv

# Unit Tests
forge test --match-contract ReputationInvariants --ffi

# Unit tests
forge test --match-contract StakeManagerTest -vv

# Invariant tests
forge test --match-contract StakeManagerInvariants

# Gas report
forge test --match-contract StakeManagerTest --gas-report

# Should now compile and run
forge test --match-contract ReputationRegistry -vv

# Run invariant tests
forge test --match-contract ReputationInvariants -vv

# Run all reputation tests
forge test --match-path test/ReputationRegistry.t.sol -vv
forge test --match-path test/invariants/ReputationInvariants.t.sol -vv

# Build
forge build

# Run all InsurancePool tests
forge test --match-contract InsurancePoolTest -vv

# Run invariant tests
forge test --match-contract InsurancePoolInvariantsTest -vv

# Run all tests
forge test -vv

# Gas report
forge test --match-contract InsurancePoolTest --gas-report