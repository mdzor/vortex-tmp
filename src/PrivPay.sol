// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PrivPayVerifier.sol";
import "forge-std/console.sol";

interface IVerifier {
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[10] memory input
    ) external view returns (bool);
}

contract PrivPay is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant TREE_DEPTH = 20;
    uint256 private constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 private constant CLAIM_PERIOD = 30 * SECONDS_PER_DAY;
    uint256 private constant CLAIMED = type(uint256).max;

    IVerifier public immutable verifier;
    mapping(bytes32 => uint256) public nullifierStatus;
    mapping(uint256 => bytes32) public commitments;
    uint256 public currentRootIndex;
    uint256 public nextIndex;
    bytes32[TREE_DEPTH] public filledSubtrees;
    bytes32[TREE_DEPTH] public roots;

    event Deposit(address indexed token, bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Claim(address indexed token, bytes32 nullifierHash, address indexed recipient, uint256 amount, uint256 timestamp);

    constructor(address _verifier) {
        verifier = IVerifier(_verifier);
    }

    function deposit(address _token, uint256 _amount, bytes32 _commitment) external payable nonReentrant {
        if (_token == address(0)) {
            require(msg.value == _amount, "Invalid ETH amount");
        } else {
            require(msg.value == 0, "ETH value must be 0 for tokens");
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        uint256 insertedIndex = _insert(_commitment);
        emit Deposit(_token, _commitment, insertedIndex, block.timestamp);
    }


    function claim(address payable _recipient, bytes calldata _proof) external nonReentrant {
        // Decode the proof and public inputs
        (
            uint256[2] memory a,
            uint256[2][2] memory b,
            uint256[2] memory c,
            uint256[5] memory input
        ) = abi.decode(_proof, (uint256[2], uint256[2][2], uint256[2], uint256[5]));

        // Extract public inputs from the proof
        bytes32 root = bytes32(input[0]);
        bytes32 nullifierHash = bytes32(input[1]);
        address token = address(uint160(input[2]));
        address recipient = address(uint160(uint256(input[3])));
        uint256 amount = input[4];

        console.log("Root:", input[0]);
        console.log("Nullifier Hash:", input[1]);
        console.log("Token:", input[2]);
        console.log("Recipient (as is):", input[3]);
        console.log("Amount:", input[4]);

        console.log("Verifying proof with inputs:");
        for (uint i = 0; i < input.length; i++) {
            console.log(input[i]);
        }
        uint256[10] memory fullInput;
        for(uint i = 0; i < 5; i++) {
            fullInput[i] = input[i];      // First 5
            fullInput[i+5] = input[i];    // Duplicate them
        }
        require(isKnownRoot(root), "Cannot find your merkle root");
        require(verifier.verifyProof(a, b, c, fullInput), "Invalid proof");

        uint256 status = nullifierStatus[nullifierHash];
        if (status == 0) {
            if (_recipient == recipient) {
                nullifierStatus[nullifierHash] = CLAIMED;
                _processTransfer(token, _recipient, amount);
            } else {
                nullifierStatus[nullifierHash] = block.timestamp;
            }
        } else if (status != CLAIMED) {
            if (_recipient == recipient) {
                nullifierStatus[nullifierHash] = CLAIMED;
                _processTransfer(token, _recipient, amount);
            } else if (block.timestamp - status > CLAIM_PERIOD) {
                nullifierStatus[nullifierHash] = CLAIMED;
                _processTransfer(token, _recipient, amount);
            } else {
                revert("Claim period not elapsed");
            }
        } else {
            revert("Already claimed");
        }
        emit Claim(token, nullifierHash, _recipient, amount, block.timestamp);
    }


    function _processTransfer(address _token, address _recipient, uint256 _amount) private {
        if (_token == address(0)) {
            require(address(this).balance >= _amount, "Insufficient ETH balance");
            payable(_recipient).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }
    }

    function isKnownRoot(bytes32 _root) public view returns (bool) {
        if (_root == 0) return false;
        uint256 i = currentRootIndex;
        do {
            if (_root == roots[i]) return true;
            if (i == 0) i = TREE_DEPTH - 1;
            else i--;
        } while (i != currentRootIndex);
        return false;
    }

    function insertRoot(bytes32 _root) external {
        roots[currentRootIndex] = _root;
        currentRootIndex = (currentRootIndex + 1) % TREE_DEPTH;
    }

    function _insert(bytes32 _leaf) internal returns (uint256 index) {
        uint256 currentIndex = nextIndex;
        require(currentIndex != uint256(2)**TREE_DEPTH, "Merkle tree is full");
        nextIndex = currentIndex + 1;
        bytes32 currentLevelHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = zeros(i);
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = keccak256(abi.encodePacked(left, right));
            currentIndex /= 2;
        }

        currentRootIndex = (currentRootIndex + 1) % TREE_DEPTH;
        roots[currentRootIndex] = currentLevelHash;
        return nextIndex - 1;
    }

function zeros(uint256 i) public pure returns (bytes32) {
        // values be precomputed off-chain and verified
        bytes32[TREE_DEPTH] memory _zeros = [
            bytes32(0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563),
            bytes32(0x633dc4d7da7256660a892f8f1604a44b5432649cc8ec5cb3ced4c4e6ac94dd1d),
            bytes32(0x890740a8eb06ce9be422cb8da5cdafc2b58c0a5e24036c578de2a433c828ff7d),
            bytes32(0x3b8ec09e026fdc305365dfc94e189a81b38c7597b3d941c279f042e8206e0bd8),
            bytes32(0xecd50eee38e386bd62be9bedb990706951b65fe053bd9d8a521af753d139e2da),
            bytes32(0xdefff6d330bb5403f63b14f33b578274160de3a50df4efecf0e0db73bcdd3da5),
            bytes32(0x617bdd11f7c0a11f49db22f629387a12da7596f9d1704d7465177c63d88ec7d7),
            bytes32(0x292c23a9aa1d8bea7e2435e555a4a60e379a5a35f3f452bae60121073fb6eead),
            bytes32(0xe1cea92ed99acdcb045a6726b2f87107e8a61620a232cf4d7d5b5766b3952e10),
            bytes32(0x7ad66c0a68c72cb89e4fb4303841966e4062a76ab97451e3b9fb526a5ceb7f82),
            bytes32(0xe026cc5a4aed3c22a58cbd3d2ac754c9352c5436f638042dca99034e83636516),
            bytes32(0x3d04cffd8b46a874edf5cfae63077de85f849a660426697b06a829c70dd1409c),
            bytes32(0xad676aa337a485e4728a0b240d92b3ef7b3c372d06d189322bfd5f61f1e7203e),
            bytes32(0xa2fca4a49658f9fab7aa63289c91b7c7b6c832a6d0e69334ff5b0a3483d09dab),
            bytes32(0x4ebfd9cd7bca2505f7bef59cc1c12ecc708fff26ae4af19abe852afe9e20c862),
            bytes32(0x2def10d13dd169f550f578bda343d9717a138562e0093b380a1120789d53cf10),
            bytes32(0x776a31db34a1a0a7caaf862cffdfff1789297ffadc380bd3d39281d340abd3ad),
            bytes32(0xe2e7610b87a5fdf3a72ebe271287d923ab990eefac64b6e59d79f8b7e08c46e3),
            bytes32(0x504364a5c6858bf98fff714ab5be9de19ed31a976860efbd0e772a2efe23e2e0),
            bytes32(0x4f05f4acb83f5b65168d9fef89d56d4d77b8944015e6b1eed81b0238e2d0dba3)
        ];
        require(i < TREE_DEPTH, "Index out of bounds");
        return _zeros[i];
    }
}