// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/PrivPayVerifier.sol";
import "../src/PrivPay.sol";

contract PrivPayTest is Test {
    PrivPay private privPay;
    Groth16Verifier private verifier;

    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[5] input;
    }

    struct PublicInputs {
        uint256 root;
        uint256 nullifierHash;
        uint256 token;
        uint256 recipient;
        uint256 amount;
    }

    Proof proof;
    PublicInputs publicInputs;


    function setUp() public {
        string memory testDataJson = vm.readFile("test/circuit_input.json");
        console.log("Raw JSON data:", testDataJson);
        
        proof.a[0] = vm.parseJsonUint(testDataJson, ".proof.a[0]");
        proof.a[1] = vm.parseJsonUint(testDataJson, ".proof.a[1]");
        
        proof.b[0][0] = vm.parseJsonUint(testDataJson, ".proof.b[0][0]");
        proof.b[0][1] = vm.parseJsonUint(testDataJson, ".proof.b[0][1]");
        proof.b[1][0] = vm.parseJsonUint(testDataJson, ".proof.b[1][0]");
        proof.b[1][1] = vm.parseJsonUint(testDataJson, ".proof.b[1][1]");
        
        proof.c[0] = vm.parseJsonUint(testDataJson, ".proof.c[0]");
        proof.c[1] = vm.parseJsonUint(testDataJson, ".proof.c[1]");
        
        for (uint i = 0; i < 5; i++) {
            proof.input[i] = vm.parseJsonUint(testDataJson, string(abi.encodePacked(".proof.input[", vm.toString(i), "]")));
        }
        
        publicInputs.root = vm.parseJsonUint(testDataJson, ".publicInputs.root");
        publicInputs.nullifierHash = vm.parseJsonUint(testDataJson, ".publicInputs.nullifierHash");
        publicInputs.token = vm.parseJsonUint(testDataJson, ".publicInputs.token");
        publicInputs.recipient = vm.parseJsonUint(testDataJson, ".publicInputs.recipient");
        publicInputs.amount = vm.parseJsonUint(testDataJson, ".publicInputs.amount");

        verifier = new Groth16Verifier();
        privPay = new PrivPay(address(verifier));

        console.log("Deployed verifier address:", address(verifier));
        console.log("PrivPay verifier address:", address(privPay.verifier()));

        bytes32 root = bytes32(proof.input[0]);
        privPay.insertRoot(root);

        // Log parsed values
        console.log("Parsed Proof A:", proof.a[0], proof.a[1]);
        console.log("Parsed Proof B1:", proof.b[0][0], proof.b[0][1]);
        console.log("Parsed Proof B2:", proof.b[1][0], proof.b[1][1]);
        console.log("Parsed Proof C:", proof.c[0], proof.c[1]);
        for (uint i = 0; i < 5; i++) {
            console.log("Parsed Input", i, ":", proof.input[i]);
        }
    }

    function testDepositClaimETH() public {
        // Generate commitment
        uint256 nullifier = 21398932366767247398525699835790934891890422694134368851583461409825672324470;
        uint256 secret = 1592396882236458605415303174009229535891206266887836906573992251145434996398;
        address payable recipient = payable(address(uint160(publicInputs.recipient)));
        uint256 amount = publicInputs.amount;

        // This should match how the commitment is created in the circuit
        bytes32 commitment = bytes32(uint256(keccak256(abi.encodePacked(nullifier, secret, recipient, amount))));

        // Deposit ETH
        bytes32 hardcodedCommitment = bytes32(uint256(8818005512962584353137638837610364273454803236005738365417990993243464585384));

        privPay.deposit{value: publicInputs.amount}(address(0), publicInputs.amount, hardcodedCommitment);

        bytes memory proofData = abi.encode(
            [proof.a[0], proof.a[1]],
            [[proof.b[0][0], proof.b[0][1]], [proof.b[1][0], proof.b[1][1]]],
            [proof.c[0], proof.c[1]],
            [proof.input[0], proof.input[1], proof.input[2], proof.input[3], proof.input[4]]
        );

        bool isKnown = privPay.isKnownRoot(bytes32(proof.input[0]));
        console.log("Is root known?", isKnown);
        uint256 balanceBefore = recipient.balance;
        privPay.claim(recipient, proofData);
        uint256 balanceAfter = recipient.balance;

        assertEq(balanceAfter - balanceBefore, publicInputs.amount);
    }

    // function testDepositClaimERC20() public {
    //     return;
    //     bytes32 commitment = bytes32(proof.input[0]);
    //     address token = address(0x1234567890123456789012345678901234567890); // Example token address
    //     address recipient = address(uint160(publicInputs.recipient));

    //     // Mock ERC20 token behavior
    //     vm.mockCall(
    //         token,
    //         abi.encodeWithSelector(IERC20.transferFrom.selector),
    //         abi.encode(true)
    //     );
    //     vm.mockCall(
    //         token,
    //         abi.encodeWithSelector(IERC20.transfer.selector),
    //         abi.encode(true)
    //     );

    //     // Deposit ERC20 tokens
    //     privPay.deposit(token, publicInputs.amount, commitment);

    //     bytes memory proofData = abi.encode(
    //         [proof.a[0], proof.a[1]],
    //         [proof.b[0], proof.b[1]],
    //         [proof.c[0], proof.c[1]],
    //         [proof.input[0], proof.input[1], proof.input[2], proof.input[3], proof.input[4]]
    //     );

    //     // Mock initial balance
    //     vm.mockCall(
    //         token,
    //         abi.encodeWithSelector(IERC20.balanceOf.selector, recipient),
    //         abi.encode(0)
    //     );
    //     uint256 balanceBefore = IERC20(token).balanceOf(recipient);

    //     privPay.claim(payable(recipient), proofData);

    //     // Mock balance after claim
    //     vm.mockCall(
    //         token,
    //         abi.encodeWithSelector(IERC20.balanceOf.selector, recipient),
    //         abi.encode(publicInputs.amount)
    //     );
    //     uint256 balanceAfter = IERC20(token).balanceOf(recipient);

    //     assertEq(balanceAfter - balanceBefore, publicInputs.amount);
    // }
}