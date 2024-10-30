const fs = require('fs');
const snarkjs = require('snarkjs');
const circomlibjs = require('circomlibjs');

async function generateRandomFieldElement(F) {
    return F.random();
}

async function generateContractTestData() {
    const poseidon = await circomlibjs.buildPoseidon();
    const F = poseidon.F;

    const nullifier = await generateRandomFieldElement(F);
    console.log("Nullifier:", F.toString(nullifier));
    const secret = await generateRandomFieldElement(F);
    console.log("Secret:", F.toString(secret));
    const recipient = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e';
    const recipientInt = BigInt(recipient) & ((1n << 160n) - 1n);
    const amount = BigInt('1000000000000000000'); // 1 ETH in wei
    const token = BigInt('0x0000000000000000000000000000000000000000'); // ETH address

    // Generate a simple Merkle tree
    const leaf = poseidon([nullifier, secret, recipientInt, amount]);
    console.log("Commitment (leaf):", F.toString(leaf));
    let currentHash = leaf;
    const path_elements = [];
    const path_indices = [];
    for (let i = 0; i < 20; i++) {
        path_elements.push(await generateRandomFieldElement(F));
        path_indices.push(0);
        currentHash = poseidon([currentHash, path_elements[i]]);
    }
    const root = currentHash;

    const nullifier_hash = poseidon([nullifier]);

    const input = {
        nullifier: F.toString(nullifier),
        secret: F.toString(secret),
        path_elements: path_elements.map(e => F.toString(e)),
        path_indices: path_indices,
        root: F.toString(root),
        nullifier_hash: F.toString(nullifier_hash),
        token: token.toString(),
        recipient: recipient.toString(),
        amount: amount.toString()
    };

    console.log("Generated input:", input);

    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        input,
        './circuits/privpay_js/privpay.wasm',
        './circuits/privpay_0001.zkey'
    );

    const contractTestData = {
        proof: {
            a: proof.pi_a,
            b: proof.pi_b,
            c: proof.pi_c,
            input: publicSignals
        },
        publicInputs: {
            root: F.toString(root),
            nullifierHash: F.toString(nullifier_hash),
            token: token.toString(),
            recipient: recipient.toString(),
            amount: amount.toString()
        }
    };

    const vKey = JSON.parse(fs.readFileSync("./circuits/verification_key.json"));
    const verified = await snarkjs.groth16.verify(vKey, publicSignals, proof);
    console.log("Proof verified locally:", verified);

    fs.writeFileSync('test/circuit_input.json', JSON.stringify(contractTestData, null, 2));
    console.log('Contract test data generated and saved to test/circuit_input.json');
}

generateContractTestData()
    .then(() => {
        console.log('Test data generation completed successfully.');
        process.exit(0);
    })
    .catch((error) => {
        console.error('An error occurred:', error);
        process.exit(1);
    });