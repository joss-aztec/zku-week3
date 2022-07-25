pragma circom 2.0.0;

// Adapted from https://github.com/enu-kuro/zku-final-project/blob/main/circuits/hitandblow.circom
// to support most variations of mastermind. The main component is configured specifically for the
// 1974 variation named "Grand Mastermind".

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

function countRequiredBits(size) {
    var total = 1;
    while (size > 2) {
        // Dividing an odd number by two doesn't truncate, and actually has a solution in the mod prime field.
        if (size % 2 == 1) size++;
        size /= 2;
        total++;
    }
    return total;
}

function countPossiblePairs(holes) {
    var total = 0;
    for (var i=0; i<holes; i++) {
        total += holes - (i + 1);
    }
    return total + 10;
}

template MastermindVariation(pegCount, holeCount) {
    assert(holeCount > 0);
    assert(holeCount <= pegCount);

    // Public inputs
    signal input pubGuess[holeCount];
    signal input pubNumHit;
    signal input pubNumBlow;
    signal input pubSolnHash;

    // Private inputs
    signal input privSoln[holeCount];
    signal input privSalt;

    // Output
    signal output solnHashOut;

    var j = 0;
    var k = 0;
    var requiredBits = countRequiredBits(pegCount);
    component lessThan[holeCount * 2];
    var possiblePairs = countPossiblePairs(holeCount);
    component equalGuess[possiblePairs];
    component equalSoln[possiblePairs];
    var equalIdx = 0;

    // Create a constraint that the solution and guess digits are all a supported pegs.
    for (j=0; j<holeCount; j++) {
        lessThan[j] = LessThan(requiredBits + 10);
        lessThan[j].in[0] <== pubGuess[j];
        lessThan[j].in[1] <== pegCount;
        lessThan[j].out === 1;
        lessThan[j+holeCount] = LessThan(10);
        lessThan[j+holeCount].in[0] <== privSoln[j];
        lessThan[j+holeCount].in[1] <== pegCount;
        lessThan[j+holeCount].out === 1;
        for (k=j+1; k<holeCount; k++) {
            // Create a constraint that the solution and guess digits are unique. no duplication.
            equalGuess[equalIdx] = IsEqual();
            equalGuess[equalIdx].in[0] <== pubGuess[j];
            equalGuess[equalIdx].in[1] <== pubGuess[k];
            equalGuess[equalIdx].out === 0;
            equalSoln[equalIdx] = IsEqual();
            equalSoln[equalIdx].in[0] <== privSoln[j];
            equalSoln[equalIdx].in[1] <== privSoln[k];
            equalSoln[equalIdx].out === 0;
            equalIdx += 1;
        }
    }

    // Count hit & blow
    var hit = 0;
    var blow = 0;
    component equalHB[holeCount * holeCount];

    for (j=0; j<holeCount; j++) {
        for (k=0; k<holeCount; k++) {
            equalHB[holeCount*j+k] = IsEqual();
            equalHB[holeCount*j+k].in[0] <== privSoln[j];
            equalHB[holeCount*j+k].in[1] <== pubGuess[k];
            blow += equalHB[holeCount*j+k].out;
            if (j == k) {
                hit += equalHB[holeCount*j+k].out;
                blow -= equalHB[holeCount*j+k].out;
            }
        }
    }

    // Create a constraint around the number of hit
    component equalHit = IsEqual();
    equalHit.in[0] <== pubNumHit;
    equalHit.in[1] <== hit;
    equalHit.out === 1;
    
    // Create a constraint around the number of blow
    component equalBlow = IsEqual();
    equalBlow.in[0] <== pubNumBlow;
    equalBlow.in[1] <== blow;
    equalBlow.out === 1;

    // Verify that the hash of the private solution matches pubSolnHash
    component poseidon = Poseidon(holeCount+1);
    poseidon.inputs[0] <== privSalt;
    for (j=0; j<holeCount; j++) {
        poseidon.inputs[j+1] <== privSoln[j];
    }

    solnHashOut <== poseidon.out;
    pubSolnHash === solnHashOut;
 }

// Grand Mastermind config
// 5 shapes * 5 colours give 25 unique pegs
// 4 holes
 component main {public [pubGuess, pubNumHit, pubNumBlow, pubSolnHash]} = MastermindVariation(25, 4);
