## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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
### Circuits

# Compile the circuit
circom ./circuits/privpay.circom --r1cs --wasm --sym -o ./circuits

# Generate a witness for the circuit (using sample input)
node ./circuits/privpay_js/generate_witness.js ./circuits/privpay_js/privpay.wasm ./circuits/input.json ./circuits/witness.wtns

# Generate a trusted setup (Phase 1)
snarkjs powersoftau new bn128 14 ./circuits/pot14_0000.ptau -v

# Contribute to the ceremony
snarkjs powersoftau contribute ./circuits/pot14_0000.ptau ./circuits/pot14_0001.ptau --name="First contribution" -v

# Phase 2
snarkjs powersoftau prepare phase2 ./circuits/pot14_0001.ptau ./circuits/pot14_final.ptau -v

# Generate a zkey file
snarkjs groth16 setup ./circuits/privpay.r1cs ./circuits/pot14_final.ptau ./circuits/privpay_0000.zkey

# Contribute to phase 2 ceremony
snarkjs zkey contribute ./circuits/privpay_0000.zkey ./circuits/privpay_0001.zkey --name="1st Contributor Name" -v

# Export the verification key
snarkjs zkey export verificationkey ./circuits/privpay_0001.zkey ./circuits/verification_key.json

# Generate Solidity verifier
snarkjs zkey export solidityverifier ./circuits/privpay_0001.zkey ./src/PrivPayVerifier.sol