pragma ton-solidity >= 0.60.0;

library EllipticCurveErrors {
    uint8 constant modulus_is_zero = 201;
    uint8 constant invalid_number = 202;
    uint8 constant invalid_compressed_ec_point_prefix = 203;
    uint8 constant use_jacdouble_function_instead = 204;
}
