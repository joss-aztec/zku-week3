const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised);
const { assert } = chai;
const { buildPoseidon } = require("circomlibjs");
const wasm_tester = require("circom_tester").wasm;

describe("MastermindVariation", () => {
  let poseidon_numStr;
  let circuit;

  beforeEach(async () => {
    poseidon_numStr = async (inputs) => {
      const poseidon = await buildPoseidon();
      const hashUint8Array = await poseidon(inputs);
      return poseidon.F.toObject(hashUint8Array).toString();
    };
    circuit = await wasm_tester(
      "contracts/circuits/MastermindVariation.circom"
    );
  });

  it("proves for a valid set of inputs", async function () {
    const privSalt = "1";
    const privSoln = ["1", "4", "2", "3"];
    const pubSolnHash = await poseidon_numStr([privSalt, ...privSoln]);
    const input = {
      pubGuess: ["1", "2", "3", "4"],
      pubNumHit: "1",
      pubNumBlow: "3",
      pubSolnHash,
      privSalt,
      privSoln,
    };
    await circuit.calculateWitness(input, true);
  });

  it("throws for an invalid set of inputs", async function () {
    const privSalt = "1";
    const privSoln = ["1", "4", "2", "3"];
    const pubSolnHash = await poseidon_numStr([privSalt, ...privSoln]);
    const input = {
      pubGuess: ["1", "2", "3", "4"],
      pubNumHit: "2",
      pubNumBlow: "3",
      pubSolnHash,
      privSalt,
      privSoln,
    };
    assert.isRejected(circuit.calculateWitness(input, true));
  });
});
