const assert = require('assert')
const Web3Utils = require('web3-utils');

let EcLib
let ecLib

let seed = 1000;

describe("EllipticCurve: Check auxiliary operations for given curves", () => {
  // /////////////////////////////////////////// //
  // Check auxiliary operations for given curves //
  // /////////////////////////////////////////// //
  const auxCurves = ["secp256k1", "P256"]

  for (const curve of auxCurves) {
    describe(`Aux. operations - Curve ${curve}`, () => {
      const curveData = require(`./data/${curve}-aux.json`)

      const pp = curveData.params.pp
      const aa = curveData.params.aa
      const bb = curveData.params.bb

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

      // toAffine
      for (const [index, test] of curveData.toAffine.valid.entries()) {
        it(`should convert a Jacobian point to affine (${index + 1})`, async function () {
          this.timeout(20000);
          const affine = await ecLib.call({
            method: 'toAffine',
            params: {
              _x: test.input.x,
              _y: test.input.y,
              _z: test.input.z,
              _pp: pp
            }
          })
          const expectedX = Web3Utils.toBN(test.output.x)
          const expectedY = Web3Utils.toBN(test.output.y)
          assert.equal(affine.value0.toString(16), expectedX.toString(16))
          assert.equal(affine.value1.toString(16), expectedY.toString(16))
        })
      }

      // invMod
      for (const [index, test] of curveData.invMod.valid.entries()) {
        it(`should invert a scalar (${index + 1}) - ${test.description}`, async function () {
          this.timeout(20000);
          const inv = await ecLib.call({
            method: 'invMod',
            params: {
              _x: test.input.k,
              _pp: pp,
            }

          })
          assert.equal(inv.toString(16), Web3Utils.toBN(test.output.k).toString(16))
        })
      }

      // invMod - invalid inputs
      /*for (const [index, test] of curveData.invMod.invalid.entries()) {
        it(`should fail when inverting with invalid inputs (${index + 1}) - ${test.description}`, async () => {
          try {
            await ecLib.invMod.call(
              Web3Utils.toBN(test.input.k),
              Web3Utils.toBN(test.input.mod),
            )
          } catch (error) {
            assert(error, test.output.error)
          }
        })
      }*/

      // expMod
      for (const [index, test] of curveData.expMod.valid.entries()) {
        it(`should do an expMod with ${test.description} - (${index + 1})`, async function () {
          this.timeout(20000);
          const exp = await ecLib.call({
            method: 'expMod',
            params: {
              _base: test.input.base,
              _exp: test.input.exp,
              _pp: pp,
            }

          })
          assert.equal(exp.toString(16), Web3Utils.toBN(test.output.k).toString(16))
        })
      }

      // deriveY
      for (const [index, test] of curveData.deriveY.valid.entries()) {
        it(`should decode coordinate y from compressed point (${index + 1})`, async function () {
          this.timeout(20000);
          const coordY = await ecLib.call({
            method: 'deriveY',
            params: {
              _prefix: test.input.sign,
              _x: test.input.x,
              _aa: aa,
              _bb: bb,
              _pp: pp
            }
          })
          assert.equal(Web3Utils.numberToHex(coordY), test.output.y)
        })
      }

      // isOnCurve
      for (const [index, test] of curveData.isOnCurve.valid.entries()) {
        it(`should identify if point is on the curve (${index + 1}) - ${test.output.isOnCurve}`, async function () {
          this.timeout(20000);
          assert.equal(
            (await ecLib.call({
              method: 'isOnCurve',
              params: {
                _x: test.input.x,
                _y: test.input.y,
                _aa: aa,
                _bb: bb,
                _pp: pp
              }
            })),
            test.output.isOnCurve
          )
        })
      }

      // invertPoint
      for (const [index, test] of curveData.invertPoint.valid.entries()) {
        it(`should invert an EC point (${index + 1})`, async function () {
          this.timeout(20000);
          const invertedPoint = await ecLib.call({
            method: 'ecInv',
            params: {
              _x: test.input.x,
              _y: test.input.y,
              _pp: pp
            }
          })
          const expectedX = Web3Utils.toBN(test.output.x)
          const expectedY = Web3Utils.toBN(test.output.y)
          assert.equal(invertedPoint.value0.toString(16), expectedX.toString(16))
          assert.equal(invertedPoint.value1.toString(16), expectedY.toString(16))
        })
      }
    })
  }
})
