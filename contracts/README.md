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

```shell
$ cp .env.example .env
```

Fill the values on `.env`, and then run:

```shell 
$ forge script --chain gnosis scripts/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast --verify -vvvv
```
