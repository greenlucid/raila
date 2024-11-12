## Raila Contracts

Raila uses Foundry for Contract deployment, dependency management, and testing.

https://book.getfoundry.sh/

## Installation

[Download and Install Foundry](https://book.getfoundry.sh/getting-started/installation)

Note there are different instructions for Windows.

### Download Dependencies

Soldeer is used for automatic handling and downloading of dependencies.

```shell
$ forge soldeer install
```

### Test

```shell
$ forge test
```

### Deploy

> todo, create a Raila.s.sol script under the `scripts/` folder. Should be deployed in Gnosis Chain, using PoHv2 as dependency.

```shell
$ forge script script/Raila.s.sol:Raila --rpc-url <your_rpc_url> --private-key <your_private_key>
```
