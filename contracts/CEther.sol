// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./CToken.sol";

/**
 * @title Compound's CEther Contract
 * @notice CToken which wraps Ether
 * @author Compound
 */
contract CEther is CToken {
    /**
     * @notice Construct a new CEther money market
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     * @param admin_ Address of the administrator of this token
     */
    
    // 这个构造函数，是CEther合约部署时，需要传入的参数。
    // 这个合约主要是为了存入ETH，所以需要传入Comptroller合约地址，InterestRateModel合约地址，初始的兑换率，名称，符号，精度，管理员地址。
    // ETH的名称是ETH，符号是ETH，精度是18位。
    constructor(ComptrollerInterface comptroller_,
                InterestRateModel interestRateModel_,
                uint initialExchangeRateMantissa_,
                string memory name_,
                string memory symbol_,
                uint8 decimals_,
                address payable admin_) {
        // Creator of the contract is admin during initialization
        // 一个奇怪的点：这里的admin是一个payable的地址。因为构造函数中的admin_是payable的。后面有赋值操作。
        admin = payable(msg.sender);

        // 原来如此。CToken中定义的initialize方法，在这里使用了。
        // 第一次见到在构造函数里出现initialize方法的。从名字来看，和构造函数的语义是一样的，都是进行一些参数初始化的。但却独立出来了。
        // 主要是因为构造函数只能调用一次。但利率模型，兑换率，名称，符号，精度，审计合约地址，都是可以升级修改的。
        initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        // Set the proper admin now that initialization is done
        admin = admin_;
    }
    /**
    这里给了一个很好的示例：一个合约中需要调用另一个合约的函数。
    在python语言中，如果A类需要调用B类的函数，那么可以在A类的构造函数中，传入B类的实例。或者在A类的某个方法中，传入B类的实例。
    在solidity语言中，如果A合约需要调用B合约的函数，那么可以在A合约的构造函数中，传入B合约的地址。或者在A合约的某个方法中，传入B合约的地址。

    注意：上面存在合约地址和合约实例的隐式转换。
    InterestRateModel interestRateModel_，
    这里的interestRateModel_是一个合约地址，但是类型是InterestRateModel。
     */


    /*** User Interface ***/

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Reverts upon any failure
     */
    // 发放的cToken仅仅是一个数字，记账在合约当中，不会真的转移给用户。
    // 当CEther合约部署后，如果我们需要存入ETH，就需要调用这个方法。这个方法被payable修饰，意味着可以接受ETH。
    // 接受的ETH数量是msg.value。发送ETH的地址是msg.sender。
    // 一个简单的猜测：这里一个储户可以给mint函数发送ETH，那么审计合约就需要检查，这个储户发送的是否是ETH。
    function mint() external payable {
        // 一个好奇：这里的Internal啥意思？意味着mintInternal函数是一个internal函数。
        /**Internal functions can only be accessed from within the current contract or contracts deriving from it. 
        They cannot be accessed externally.  
         */
        mintInternal(msg.value);
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    // 这里会进行赎回存储资产的操作。输入的参数是cToken的数量。
    // 一个猜测：函数内部肯定会对cToken的数量进行检查。如果赎回的数量超过了用户的cToken数量，那么就会报错。
    function redeem(uint redeemTokens) external returns (uint) {
        redeemInternal(redeemTokens);
        return NO_ERROR;
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        redeemUnderlyingInternal(redeemAmount);
        return NO_ERROR;
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    // 盲猜一下：这里的borrowAmount是用户想要借入的ETH数量。
    // 首先会调用审计合约函数，检查用户是否可以借入这么多的ETH。
    // 如果允许，就会从资金池转入这么多的ETH到用户的地址。
    // 合约的资金池的余额是balance，用户的地址是msg.sender。
    // 从资金流向的角度来看，borrow和redeem是一样的，都是从资金池流向用户的地址。
    // 从代码的角度来看，实现逻辑也比较类似。
    function borrow(uint borrowAmount) external returns (uint) {
        borrowInternal(borrowAmount);
        return NO_ERROR;
    }

    /**
     * @notice Sender repays their own borrow
     * @dev Reverts upon any failure
     */
    // 注意这个函数的修饰符：payable。意味着这个函数可以接受ETH。
    // 当我们要还款的时候，就可以调用这个函数，将ETH发送给合约。
    function repayBorrow() external payable {
        repayBorrowInternal(msg.value);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @dev Reverts upon any failure
     * @param borrower the account with the debt being payed off
     */
    function repayBorrowBehalf(address borrower) external payable {
        repayBorrowBehalfInternal(borrower, msg.value);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @dev Reverts upon any failure
     * @param borrower The borrower of this cToken to be liquidated
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     */
    /**
    清算，任何人都可以调用此函数来担任清算人，直接借款人、还款金额和清算的 cToken 资产，
    清算时，清算人帮借款人代还款，并得到借款人所抵押的等值+清算奖励的 cToken 资产。
     */
    // 注意这里的函数修饰符：payable。意味着这个函数可以接受ETH。也就是说，清算人向合约发送ETH。
    // 任何人都可以调用这个函数，付出的是ETH，得到的是CEther。
    // 有一个疑问：如果我向资金池存储了ETH，获得了CEther。如果我想借入DAI，怎么办呢？
    // 对于借贷，需要明确一个基本概念：抵押物是CEther，借出的是ETH。从下面函数的参数类型可以看出来。
    // 执行清算的时候，清算人需要向合约发送ETH，得到的是CEther。
    // 注意函数的修饰符：payable。意味着这个函数可以接受ETH。
    function liquidateBorrow(address borrower, CToken cTokenCollateral) external payable {
        liquidateBorrowInternal(borrower, msg.value, cTokenCollateral);
    }

    /**
     * @notice The sender adds to reserves.
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _addReserves() external payable returns (uint) {
        return _addReservesInternal(msg.value);
    }

    /**
     * @notice Send Ether to CEther to mint
     */
    receive() external payable {
        mintInternal(msg.value);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of Ether, before this message
     * @dev This excludes the value of the current message, if any
     * @return The quantity of Ether owned by this contract
     */
    function getCashPrior() override internal view returns (uint) {
        // 这个设计！！！减去了当前的msg.value。这个msg.value是用户发送的ETH。
        // 思考的真是全面!
        return address(this).balance - msg.value;
    }

    /**
     * @notice Perform the actual transfer in, which is a no-op
     * @param from Address sending the Ether
     * @param amount Amount of Ether being sent
     * @return The actual amount of Ether transferred
     */
    function doTransferIn(address from, uint amount) override internal returns (uint) {
        // Sanity checks
        require(msg.sender == from, "sender mismatch");
        require(msg.value == amount, "value mismatch");
        return amount;
    }

    function doTransferOut(address payable to, uint amount) virtual override internal {
        /* Send the Ether, with minimal gas and revert on failure */
        to.transfer(amount);
    }
}
