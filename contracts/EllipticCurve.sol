pragma ton-solidity >= 0.60.0;

import './EllipticCurveErrors.sol';

library EllipticCurve {

  // Pre-computed constant for 2 ** 255
  uint256 constant private U255_MAX_PLUS_1 = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

  function isZero(uint256 _x) internal returns (uint256) {
    if (_x == 0) {
      return 1;
    } else {
      return 0;
    }
  }

  function addMod(uint256 _x, uint256 _y, uint256 _pp) internal returns (uint256) {
    _x = _x % _pp;
    _y = _y % _pp;
    if (_y == 0) {
      return _x;
    }
    _y = _pp - _y;
    if (_x >= _y) {
      return _x - _y;
    } else {
      return _pp - _y + _x;
    }

    //return ((_x % _pp) + (_y % _pp)) % _pp;
  }

  function mulMod(uint256 _x, uint256 _y, uint256 _pp) internal returns (uint256) {
    require(_pp != 0, EllipticCurveErrors.modulus_is_zero);
    
    if (_x == 0 || _y == 0) {
      return 0;
    }

    uint256 r = 0;
    _x = _x % _pp;
    _y = _y % _pp;
    while (_y > 0) {
      if (_y & 1 != 0) {
        r = addMod(r, _x, _pp);
      }
      _x = addMod(_x, _x, _pp);
      _y = _y >> 1;
    }
    return r;

  }

  /// @dev Modular euclidean inverse of a number (mod p).
  /// @param _x The number
  /// @param _pp The modulus
  /// @return q such that x*q = 1 (mod _pp)
  function invMod(uint256 _x, uint256 _pp) internal returns (uint256) {
    require(_x != 0 && _x != _pp && _pp != 0, EllipticCurveErrors.invalid_number);
    uint256 q = 0;
    uint256 newT = 1;
    uint256 r = _pp;
    uint256 t;
    while (_x != 0) {
      t = r / _x;
      (q, newT) = (newT, addMod(q, (_pp - mulMod(t, newT, _pp)), _pp));
      (r, _x) = (_x, r - t * _x);
    }

    return q;
  }

  /// @dev Modular exponentiation, b^e % _pp.
  /// Source: https://github.com/androlo/standard-contracts/blob/master/contracts/src/crypto/ECCMath.sol
  /// @param _base base
  /// @param _exp exponent
  /// @param _pp modulus
  /// @return r such that r = b**e (mod _pp)
  function expMod(uint256 _base, uint256 _exp, uint256 _pp) internal returns (uint256) {
    require(_pp != 0, EllipticCurveErrors.modulus_is_zero);

    if (_base == 0)
      return 0;
    if (_exp == 0)
      return 1;

    uint256 r = 1;
    uint256 bit = U255_MAX_PLUS_1;
    while (bit > 0) {
      r = mulMod(mulMod(r, r, _pp), (_base ** isZero(isZero(_exp & bit))), _pp);
      r = mulMod(mulMod(r, r, _pp), (_base ** isZero(isZero(_exp & (bit / 2)))), _pp);
      r = mulMod(mulMod(r, r, _pp), (_base ** isZero(isZero(_exp & (bit / 4)))), _pp);
      r = mulMod(mulMod(r, r, _pp), (_base ** isZero(isZero(_exp & (bit / 8)))), _pp);
      bit = bit / 16;
    }

    return r;
  }

  /// @dev Converts a point (x, y, z) expressed in Jacobian coordinates to affine coordinates (x', y', 1).
  /// @param _x coordinate x
  /// @param _y coordinate y
  /// @param _z coordinate z
  /// @param _pp the modulus
  /// @return (x', y') affine coordinates
  function toAffine(
    uint256 _x,
    uint256 _y,
    uint256 _z,
    uint256 _pp)
  internal returns (uint256, uint256)
  {
    uint256 zInv = invMod(_z, _pp);
    uint256 zInv2 = mulMod(zInv, zInv, _pp);
    uint256 x2 = mulMod(_x, zInv2, _pp);
    uint256 y2 = mulMod(_y, mulMod(zInv, zInv2, _pp), _pp);

    return (x2, y2);
  }

  /// @dev Derives the y coordinate from a compressed-format point x [[SEC-1]](https://www.secg.org/SEC1-Ver-1.0.pdf).
  /// @param _prefix parity byte (0x02 even, 0x03 odd)
  /// @param _x coordinate x
  /// @param _aa constant of curve
  /// @param _bb constant of curve
  /// @param _pp the modulus
  /// @return y coordinate y
  function deriveY(
    uint8 _prefix,
    uint256 _x,
    uint256 _aa,
    uint256 _bb,
    uint256 _pp)
  internal returns (uint256)
  {
    require(_prefix == 0x02 || _prefix == 0x03, EllipticCurveErrors.invalid_compressed_ec_point_prefix);

    // x^3 + ax + b
    uint256 y2 = addMod(mulMod(_x, mulMod(_x, _x, _pp), _pp), addMod(mulMod(_x, _aa, _pp), _bb, _pp), _pp);
    y2 = expMod(y2, (_pp + 1) / 4, _pp);
    // uint256 cmp = yBit ^ y_ & 1;
    uint256 y = (y2 + _prefix) % 2 == 0 ? y2 : _pp - y2;

    return y;
  }

  /// @dev Check whether point (x,y) is on curve defined by a, b, and _pp.
  /// @param _x coordinate x of P1
  /// @param _y coordinate y of P1
  /// @param _aa constant of curve
  /// @param _bb constant of curve
  /// @param _pp the modulus
  /// @return true if x,y in the curve, false else
  function isOnCurve(
    uint256 _x,
    uint256 _y,
    uint256 _aa,
    uint256 _bb,
    uint256 _pp)
  internal returns (bool)
  {
    if (0 == _x || _x >= _pp || 0 == _y || _y >= _pp) {
      return false;
    }
    // y^2
    uint256 lhs = mulMod(_y, _y, _pp);
    // x^3
    uint256 rhs = mulMod(mulMod(_x, _x, _pp), _x, _pp);
    if (_aa != 0) {
      // x^3 + a*x
      rhs = addMod(rhs, mulMod(_x, _aa, _pp), _pp);
    }
    if (_bb != 0) {
      // x^3 + a*x + b
      rhs = addMod(rhs, _bb, _pp);
    }

    return lhs == rhs;
  }

  /// @dev Calculate inverse (x, -y) of point (x, y).
  /// @param _x coordinate x of P1
  /// @param _y coordinate y of P1
  /// @param _pp the modulus
  /// @return (x, -y)
  function ecInv(
    uint256 _x,
    uint256 _y,
    uint256 _pp)
  internal returns (uint256, uint256)
  {
    return (_x, (_pp - _y) % _pp);
  }

  /// @dev Add two points (x1, y1) and (x2, y2) in affine coordinates.
  /// @param _x1 coordinate x of P1
  /// @param _y1 coordinate y of P1
  /// @param _x2 coordinate x of P2
  /// @param _y2 coordinate y of P2
  /// @param _aa constant of the curve
  /// @param _pp the modulus
  /// @return (qx, qy) = P1+P2 in affine coordinates
  function ecAdd(
    uint256 _x1,
    uint256 _y1,
    uint256 _x2,
    uint256 _y2,
    uint256 _aa,
    uint256 _pp)
    internal returns(uint256, uint256)
  {
    uint256 x = 0;
    uint256 y = 0;
    uint256 z = 0;

    // Double if x1==x2 else add
    if (_x1==_x2) {
      // y1 = -y2 mod p
      if (addMod(_y1, _y2, _pp) == 0) {
        return(0, 0);
      } else {
        // P1 = P2
        (x, y, z) = jacDouble(
          _x1,
          _y1,
          1,
          _aa,
          _pp);
      }
    } else {
      (x, y, z) = jacAdd(
        _x1,
        _y1,
        1,
        _x2,
        _y2,
        1,
        _pp);
    }
    // Get back to affine
    return toAffine(
      x,
      y,
      z,
      _pp);
  }

  /// @dev Substract two points (x1, y1) and (x2, y2) in affine coordinates.
  /// @param _x1 coordinate x of P1
  /// @param _y1 coordinate y of P1
  /// @param _x2 coordinate x of P2
  /// @param _y2 coordinate y of P2
  /// @param _aa constant of the curve
  /// @param _pp the modulus
  /// @return (qx, qy) = P1-P2 in affine coordinates
  function ecSub(
    uint256 _x1,
    uint256 _y1,
    uint256 _x2,
    uint256 _y2,
    uint256 _aa,
    uint256 _pp)
  internal returns(uint256, uint256)
  {
    // invert square
    (uint256 x, uint256 y) = ecInv(_x2, _y2, _pp);
    // P1-square
    return ecAdd(
      _x1,
      _y1,
      x,
      y,
      _aa,
      _pp);
  }

  /// @dev Multiply point (x1, y1, z1) times d in affine coordinates.
  /// @param _k scalar to multiply
  /// @param _x coordinate x of P1
  /// @param _y coordinate y of P1
  /// @param _aa constant of the curve
  /// @param _pp the modulus
  /// @return (qx, qy) = d*P in affine coordinates
  function ecMul(
    uint256 _k,
    uint256 _x,
    uint256 _y,
    uint256 _aa,
    uint256 _pp)
  internal returns(uint256, uint256)
  {
    // Jacobian multiplication
    (uint256 x1, uint256 y1, uint256 z1) = jacMul(
      _k,
      _x,
      _y,
      1,
      _aa,
      _pp);
    // Get back to affine
    return toAffine(
      x1,
      y1,
      z1,
      _pp);
  }

  /// @dev Adds two points (x1, y1, z1) and (x2 y2, z2).
  /// @param _x1 coordinate x of P1
  /// @param _y1 coordinate y of P1
  /// @param _z1 coordinate z of P1
  /// @param _x2 coordinate x of square
  /// @param _y2 coordinate y of square
  /// @param _z2 coordinate z of square
  /// @param _pp the modulus
  /// @return (qx, qy, qz) P1+square in Jacobian
  function jacAdd(
    uint256 _x1,
    uint256 _y1,
    uint256 _z1,
    uint256 _x2,
    uint256 _y2,
    uint256 _z2,
    uint256 _pp)
  internal returns (uint256, uint256, uint256)
  {
    if (_x1==0 && _y1==0)
      return (_x2, _y2, _z2);
    if (_x2==0 && _y2==0)
      return (_x1, _y1, _z1);

    // We follow the equations described in https://pdfs.semanticscholar.org/5c64/29952e08025a9649c2b0ba32518e9a7fb5c2.pdf Section 5
    /*uint256[] zs = new uint256[](4); // z1^2, z1^3, z2^2, z2^3
    zs[0] = mulMod(_z1, _z1, _pp);
    zs[1] = mulMod(_z1, zs[0], _pp);
    zs[2] = mulMod(_z2, _z2, _pp);
    zs[3] = mulMod(_z2, zs[2], _pp);*/

    uint256 z12 = mulMod(_z1, _z1, _pp);
    uint256 z13 = mulMod(_z1, z12, _pp);
    uint256 z22 = mulMod(_z2, _z2, _pp);
    uint256 z23 = mulMod(_z2, z22, _pp);

    // u1, s1, u2, s2
    /*zs = [
      mulMod(_x1, zs[2], _pp),
      mulMod(_y1, zs[3], _pp),
      mulMod(_x2, zs[0], _pp),
      mulMod(_y2, zs[1], _pp)
    ];*/

    uint256 u1 = mulMod(_x1, z22, _pp);
    uint256 s1 = mulMod(_y1, z23, _pp);
    uint256 u2 = mulMod(_x2, z12, _pp);
    uint256 s2 = mulMod(_y2, z13, _pp);

    // In case of zs[0] == zs[2] && zs[1] == zs[3], double function should be used
    require(u1 != u2 || s1 !=s2, EllipticCurveErrors.use_jacdouble_function_instead);

    /*uint256[] hr = new uint256[](4);
    //h
    hr[0] = addMod(zs[2], _pp - zs[0], _pp);
    //r
    hr[1] = addMod(zs[3], _pp - zs[1], _pp);
    //h^2
    hr[2] = mulMod(hr[0], hr[0], _pp);
    // h^3
    hr[3] = mulMod(hr[2], hr[0], _pp);*/

    uint256 h = addMod(u2, _pp - u1, _pp);
    uint256 r = addMod(s2, _pp - s1, _pp);
    uint256 h2 = mulMod(h, h, _pp);
    uint256 h3 =  mulMod(h2, h, _pp);


    // qx = -h^3  -2u1h^2+r^2
    uint256 qx = addMod(mulMod(r,r, _pp), _pp - h3, _pp);
    qx = addMod(qx, _pp - mulMod(2, mulMod(u1, h2, _pp), _pp), _pp);
    // qy = -s1*z1*h^3+r(u1*h^2 -x^3)
    uint256 qy = mulMod(r, addMod(mulMod(u1, h2, _pp), _pp - qx, _pp), _pp);
    qy = addMod(qy, _pp - mulMod(s1, h3, _pp), _pp);
    // qz = h*z1*z2
    uint256 qz = mulMod(h, mulMod(_z1, _z2, _pp), _pp);
    return(qx, qy, qz);
  }

  /// @dev Doubles a points (x, y, z).
  /// @param _x coordinate x of P1
  /// @param _y coordinate y of P1
  /// @param _z coordinate z of P1
  /// @param _aa the a scalar in the curve equation
  /// @param _pp the modulus
  /// @return (qx, qy, qz) 2P in Jacobian
  function jacDouble(
    uint256 _x,
    uint256 _y,
    uint256 _z,
    uint256 _aa,
    uint256 _pp)
  internal returns (uint256, uint256, uint256)
  {
    if (_z == 0)
      return (_x, _y, _z);

    // We follow the equations described in https://pdfs.semanticscholar.org/5c64/29952e08025a9649c2b0ba32518e9a7fb5c2.pdf Section 5
    // Note: there is a bug in the paper regarding the m parameter, M=3*(x1^2)+a*(z1^4)
    // x, y, z at this point represent the squares of _x, _y, _z
    uint256 x = mulMod(_x, _x, _pp); //x1^2
    uint256 y = mulMod(_y, _y, _pp); //y1^2
    uint256 z = mulMod(_z, _z, _pp); //z1^2

    // s
    uint256 s = mulMod(4, mulMod(_x, y, _pp), _pp);
    // m
    uint256 m = addMod(mulMod(3, x, _pp), mulMod(_aa, mulMod(z, z, _pp), _pp), _pp);

    // x, y, z at this point will be reassigned and rather represent qx, qy, qz from the paper
    // This allows to reduce the gas cost and stack footprint of the algorithm
    // qx
    x = addMod(mulMod(m, m, _pp), _pp - addMod(s, s, _pp), _pp);
    // qy = -8*y1^4 + M(S-T)
    y = addMod(mulMod(m, addMod(s, _pp - x, _pp), _pp), _pp - mulMod(8, mulMod(y, y, _pp), _pp), _pp);
    // qz = 2*y1*z1
    z = mulMod(2, mulMod(_y, _z, _pp), _pp);

    return (x, y, z);
  }

  /// @dev Multiply point (x, y, z) times d.
  /// @param _d scalar to multiply
  /// @param _x coordinate x of P1
  /// @param _y coordinate y of P1
  /// @param _z coordinate z of P1
  /// @param _aa constant of curve
  /// @param _pp the modulus
  /// @return (qx, qy, qz) d*P1 in Jacobian
  function jacMul(
    uint256 _d,
    uint256 _x,
    uint256 _y,
    uint256 _z,
    uint256 _aa,
    uint256 _pp)
  internal returns (uint256, uint256, uint256)
  {
    // Early return in case that `_d == 0`
    if (_d == 0) {
      return (_x, _y, _z);
    }

    uint256 remaining = _d;
    uint256 qx = 0;
    uint256 qy = 0;
    uint256 qz = 1;

    // Double and add algorithm
    while (remaining != 0) {
      if ((remaining & 1) != 0) {
        (qx, qy, qz) = jacAdd(
          qx,
          qy,
          qz,
          _x,
          _y,
          _z,
          _pp);
      }
      remaining = remaining >> 1;
      (_x, _y, _z) = jacDouble(
        _x,
        _y,
        _z,
        _aa,
        _pp);
    }
    return (qx, qy, qz);
  }
}