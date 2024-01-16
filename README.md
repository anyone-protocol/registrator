# Registrator
`Registrator` contract is allowing users to transfer a pre-defined amount of tokens that will be accounted for the purpose of relay registration. Contract operator can set a conversion rate of the input tokens to registration credits.

These registration accounts can be:
* checked to verify registration status
* slashed by admins in response to relay misbehavior

Built on top of the [OpenZeppelin framework](https://openzeppelin.com/), developed using [HardHat env](https://hardhat.org/).

## Install
```bash
$ npm i
```

## Test
```bash
$ npx hardhat test --network localhost
```

## Deploy (dev)
```bash
$ npx hardhat run --network localhost scripts/deploy.ts
```