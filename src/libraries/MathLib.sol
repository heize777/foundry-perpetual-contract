// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

library MathLib {
    function abs(int256 x) public pure returns (int256) {
        return x > 0 ? x : -x;
    }
}
