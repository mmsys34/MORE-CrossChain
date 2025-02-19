# <h1 align="center"> Hardhat x Foundry Template </h1>

**Template repository for getting started quickly with Hardhat and Foundry in one project**

## Requirments
- Foundry: https://book.getfoundry.sh/getting-started/installation
- Hardhat: https://hardhat.org/docs


## Installation
Follow https://book.getfoundry.sh/getting-started/installation
- Install the submodule dependencies:
```sh
forge install
```

- Install NPM packages:
```sh
npm install
```

## Build or Compile
```sh
npm run build
```
#### Or
```sh
npm run compile
```

## Test
The unit tests are written in Solidity and Foundry.
- Run all tests:
```sh
npm run test
```

- Get a gas report:
```sh
npm run test:gas
```

## Coverage
Get a test coverage report:

```sh
npm run coverage
```

## Clean
Delete the build artifacts and cache directories:

```sh
npm run clean
```
