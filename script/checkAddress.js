const { ethers } = require('ethers');

// The large integer representation of the address
const integerAddress = '121538088673429312715437000977479329117';

// Convert to hexadecimal and pad to 40 characters (20 bytes)
const hexAddress = BigInt(integerAddress).toString(16).padStart(40, '0');

// Create an Ethereum address
const ethereumAddress = ethers.getAddress('0x' + hexAddress);

console.log('Integer:', integerAddress);
console.log('Hex:', hexAddress);
console.log('Ethereum Address:', ethereumAddress);