const { groth16 } = require('snarkjs');
const fs = require('fs');

const testData = JSON.parse(fs.readFileSync("test/circuit_input.json"));

const proof = {
    pi_a: testData.proof.a,
    pi_b: testData.proof.b,
    pi_c: testData.proof.c
};

const publicSignals = testData.proof.input;

async function verifyProof() {
    console.log("Starting verification of test case proof...");
    const vKey = JSON.parse(fs.readFileSync("./circuits/verification_key.json"));
    console.log("proof:", proof);
    console.log("vKey:",vKey);
    const verified = await groth16.verify(vKey, publicSignals, proof);
    console.log("Test case proof verified locally:", verified);
}

verifyProof()
    .then(() => {
        process.exit(0);
    })
    .catch((error) => {
        console.error('An error occurred:', error);
        process.exit(1);
    });