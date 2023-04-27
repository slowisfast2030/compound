// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";

abstract contract PriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
      * @notice Get the underlying price of a cToken asset
      * @param cToken The cToken to get the underlying price of
      * @return The underlying asset price mantissa (scaled by 1e18).
      *  Zero means the price is unavailable.
      */
    // 函数名中的underlying表示底层资产，即cToken对应的标的资产
    function getUnderlyingPrice(CToken cToken) virtual external view returns (uint);
}

/**
  价格预言机是DeFi借贷产品中必不可少的组成部分。
  它们用于确定抵押品的价值，以确定借款人可以借多少钱（债务）。
  Compound使用PriceOracle接口来获取抵押品的价值。
  这个接口只有一个方法，getUnderlyingPrice，它接受一个CToken并返回一个uint。
  这个uint是抵押品的价值，以18位小数表示。例如，如果抵押品价值100美元，getUnderlyingPrice将返回100e18。
  可以进一步思考，为何需要将价格乘以1e18？
 */