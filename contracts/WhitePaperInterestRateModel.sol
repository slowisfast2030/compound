// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./InterestRateModel.sol";

/**
  * @title Compound's WhitePaperInterestRateModel Contract
  * @author Compound
  * @notice The parameterized model described in section 2.4 of the original Compound Protocol whitepaper
  */
contract WhitePaperInterestRateModel is InterestRateModel {
    event NewInterestParams(uint baseRatePerBlock, uint multiplierPerBlock);

    /**
    This particular constant variable BASE is often used in smart contracts as a scaling factor for decimal numbers. 
    For example, if a smart contract was dealing with Ether transactions, 
    then the amount of ether would be represented as wei, where one ether is equal to 1e18 wei.
     */
    uint256 private constant BASE = 1e18;

    /**
     * @notice The approximate number of blocks per year that is assumed by the interest rate model
     */
    uint public constant blocksPerYear = 2102400;

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint public multiplierPerBlock;

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint public baseRatePerBlock;

    /**
     * @notice Construct an interest rate model
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by BASE)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by BASE)
     */

    // baseRatePerYear = 0.05 * 1e18
    // multiplierPerYear = 0.45 * 1e18
    // 这两个参数为何scaled by BASE? 
    // 进而baseRatePerBlock和multiplierPerBlock也scaled by BASE
    // 这两个参数就是y = kx + b中的k和b
    // 部署新的利率模型的时候，会初始化这两个参数
    constructor(uint baseRatePerYear, uint multiplierPerYear) public {
        // 这里需要进一步理解单利和复利
        // 单利：只有本金产生利息，利息不产生利息
        // 复利：本金和利息都产生利息
        // 这里将年利率除以了一年的区块数，得到了每个区块的利率
        // 很明显，这里的利率是单利
        baseRatePerBlock = baseRatePerYear / blocksPerYear;
        multiplierPerBlock = multiplierPerYear / blocksPerYear;

        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock);
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, BASE]
     */

     // utilizationRate也放大了BASE倍，为何？
    function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }
        // 这里减去了准备金，会使得资金使用率变大，从而借款利率和存款利率都增加
        return borrows * BASE / (cash + borrows - reserves);
    }

    /**
     * @notice Calculates the current borrow rate per block, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by BASE)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) override public view returns (uint) {
        uint ur = utilizationRate(cash, borrows, reserves);
        // ur放大了BASE倍
        // multiplierPerBlock放大了BASE倍
        // baseRatePerBlock放大了BASE倍
        // 为了使得最终的borrowRate放大了BASE倍，所以这里需要除以BASE
        return (ur * multiplierPerBlock / BASE) + baseRatePerBlock;
    }

    /**
     * @notice Calculates the current supply rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @param reserveFactorMantissa The current reserve factor for the market
     * @return The supply rate percentage per block as a mantissa (scaled by BASE)
     */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) override public view returns (uint) {
        // oneMinusReserveFactor本质上是一个百分比，表示可以借出去的钱的比例。这里放大了BASE倍
        uint oneMinusReserveFactor = BASE - reserveFactorMantissa;
        // borrowRate放大了BASE倍
        uint borrowRate = getBorrowRate(cash, borrows, reserves);
        // rateToPool放大了BASE倍
        uint rateToPool = borrowRate * oneMinusReserveFactor / BASE;
        // utilizationRate放大了BASE倍，rateToPool放大了BASE倍，所以最终的存款利率放大了BASE倍
        return utilizationRate(cash, borrows, reserves) * rateToPool / BASE;
        // 总结起来就是：存款利率 = 资金使用率 * 借款利率 *（1 - 储备金率）
    }
}

/**
总结：
1. 这个利率模型是基于白皮书的利率模型，即y = kx + b
2. 这个利率模型的利率是单利，而不是复利
3. 不考虑准备金，理解起来会更加简单
*/