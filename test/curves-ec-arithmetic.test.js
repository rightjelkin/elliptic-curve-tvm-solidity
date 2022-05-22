const assert = require('assert')
const Web3Utils = require('web3-utils');

let EcLib
let ecLib

let seed = 2000;

describe("EllipticCurve: Check EC arithmetic operations for given curves", () => {
  // /////////////////////////////////////////////// //
  // Check EC arithmetic operations for given curves //
  // /////////////////////////////////////////////// //
  const curves = ["secp256k1", "secp192k1", "secp224k1", "P256", "P192", "P224"]

  for (const curve of curves) {
    describe(`Arithmetic operations - Curve ${curve}`, () => {
      const curveData = require(`./data/${curve}.json`)

      const pp = curveData.params.pp
      const aa = curveData.params.aa

      let ecLib
      before(async function () {
        this.timeout(20000);
        EcLib = await locklift.factory.getContract('TestEllipticCurve');
        const [keyPair] = await locklift.keys.getKeyPairs();
        ecLib = await locklift.giver.deployContract({
          contract: EcLib,
          constructorParams: {},
          initParams: { deploySeed: seed++ },
          keyPair,
        });
      })

      // Addition
      for (const [index, test] of curveData.addition.valid.entries()) {
        it(`should add two numbers (${index + 1}) - ${test.description}`, async function () {
          this.timeout(20000);
          const res = await ecLib.call({
            method: 'ecAdd',
            params: {
              _x1: test.input.x1,
              _y1: test.input.y1,
              _x2: test.input.x2,
              _y2: test.input.y2,
              _aa: aa,
              _pp: pp
            }
          })
          const expectedSumX = Web3Utils.toBN(test.output.x)
          const expectedSumZ = Web3Utils.toBN(test.output.y)
          assert.equal(res.value0.toString(16), expectedSumX.toString(16))
          assert.equal(res.value1.toString(16), expectedSumZ.toString(16))
        })
      }

      // Subtraction
      for (const [index, test] of curveData.subtraction.valid.entries()) {
        it(`should subtract two numbers (${index + 1}) - ${test.description}`, async function () {
          this.timeout(20000);
          const res = await ecLib.call({
            method: 'ecSub',
            params: {
              _x1: test.input.x1,
              _y1: test.input.y1,
              _x2: test.input.x2,
              _y2: test.input.y2,
              _aa: aa,
              _pp: pp
            }
          })
          const expectedSubX = Web3Utils.toBN(test.output.x)
          const expectedSubY = Web3Utils.toBN(test.output.y)
          assert.equal(res.value0.toString(16), expectedSubX.toString(16))
          assert.equal(res.value1.toString(16), expectedSubY.toString(16))
        })
      }

      // Multiplication
      for (const [index, test] of curveData.multiplication.valid.entries()) {
        it(`should multiply EC points (${index + 1}) - ${test.description}`, async function () {
          this.timeout(20000);
          const res = await ecLib.call({
            method: 'ecMul',
            params: {
              _k: Web3Utils.numberToHex(Web3Utils.toBN(test.input.k)),
              _x: test.input.x,
              _y: test.input.y,
              _aa: aa,
              _pp: pp
            }

          })
          const expectedMulX = Web3Utils.toBN(test.output.x)
          const expectedMulY = Web3Utils.toBN(test.output.y)
          assert.equal(res.value0.toString(16), expectedMulX.toString(16))
          assert.equal(res.value1.toString(16), expectedMulY.toString(16))
        })
      }
    })
  }
})
