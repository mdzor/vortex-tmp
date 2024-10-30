const fs = require('fs');
const circomlibjs = require('circomlibjs');

async function main() {
    const poseidon = await circomlibjs.buildPoseidon();

    const nullifier = 123456789n;
    const secret = 987654321n;
    const recipient = 2000000000000000000000000000000000000000n;
    const amount = 1000000000000000000n;
    const token = 1157920892373161954235709850086879078532699846656405640394575840079131296399n;

    const commitment = poseidon([nullifier, secret, recipient, amount]);
    const nullifier_hash = poseidon([nullifier]);

    const path_elements = Array(20).fill(0n);
    const path_indices = Array(20).fill(0);

    let current_hash = commitment;
    for (let i = 0; i < 20; i++) {
        current_hash = poseidon([current_hash, path_elements[i]]);
    }

    const root = current_hash;

    const input_data = {
        nullifier: nullifier.toString(),
        secret: secret.toString(),
        path_elements: path_elements.map(x => x.toString()),
        path_indices: path_indices,
        root: poseidon.F.toString(root),
        nullifier_hash: poseidon.F.toString(nullifier_hash),
        token: token.toString(),
        recipient: recipient.toString(),
        amount: amount.toString()
    };

    fs.writeFileSync('./circuits/input.json', JSON.stringify(input_data, null, 2));
}

main().catch(console.error);