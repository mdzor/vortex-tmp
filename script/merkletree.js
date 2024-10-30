const { ethers } = require('ethers');

function generateZeros(depth) {
    let zeros = [];
    zeros[0] = ethers.keccak256(ethers.zeroPadValue('0x00', 32));
    for (let i = 1; i < depth; i++) {
        zeros[i] = ethers.keccak256(ethers.concat([zeros[i-1], zeros[i-1]]));
    }
    return zeros;
}

const zeros = generateZeros(20);
console.log(zeros.map(z => `bytes32(${z}),`).join('\n'));