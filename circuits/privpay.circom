pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

template MerkleTreeChecker(levels) {
    signal input leaf;
    signal input path_elements[levels];
    signal input path_indices[levels];
    signal output root;

    component poseidons[levels];
    component mux[levels];

    signal levelHashes[levels + 1];
    levelHashes[0] <== leaf;

    for (var i = 0; i < levels; i++) {
        poseidons[i] = Poseidon(2);
        mux[i] = Mux1();

        mux[i].c[0] <== levelHashes[i];
        mux[i].c[1] <== path_elements[i];
        mux[i].s <== path_indices[i];

        poseidons[i].inputs[0] <== mux[i].out;
        poseidons[i].inputs[1] <== path_elements[i] + levelHashes[i] - mux[i].out;

        levelHashes[i + 1] <== poseidons[i].out;
    }

    root <== levelHashes[levels];
}

template PrivPay(levels) {
    // Private inputs
    signal input nullifier;
    signal input secret;
    signal input path_elements[levels];
    signal input path_indices[levels];

    // Public inputs
    signal input root;
    signal input nullifier_hash;
    signal input token;
    signal input recipient;
    signal input amount;

    // Compute nullifier hash
    component nullifier_hasher = Poseidon(1);
    nullifier_hasher.inputs[0] <== nullifier;
    nullifier_hash === nullifier_hasher.out;

    // Compute commitment
    component commitment_hasher = Poseidon(4);
    commitment_hasher.inputs[0] <== nullifier;
    commitment_hasher.inputs[1] <== secret;
    commitment_hasher.inputs[2] <== recipient;
    commitment_hasher.inputs[3] <== amount;

    // Check merkle proof
    component tree_checker = MerkleTreeChecker(levels);
    tree_checker.leaf <== commitment_hasher.out;
    for (var i = 0; i < levels; i++) {
        tree_checker.path_elements[i] <== path_elements[i];
        tree_checker.path_indices[i] <== path_indices[i];
    }
    tree_checker.root === root;

    // Public outputs
    signal output computed_root;
    signal output computed_nullifier_hash;
    signal output computed_token;
    signal output computed_recipient;
    signal output computed_amount;

    computed_root <== root;
    computed_nullifier_hash <== nullifier_hash;
    computed_token <== token;
    computed_recipient <== recipient;
    computed_amount <== amount;
}

component main {public [root, nullifier_hash, token, recipient, amount]} = PrivPay(20);