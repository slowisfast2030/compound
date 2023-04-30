// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./ErrorReporter.sol";
import "./ComptrollerStorage.sol";

/**
msg.sender ----> Unitroller  -----> ComptrollerG1
                             -----> ComptrollerG2
                             .....
                             -----> ComptrollerG7
 
 文章：https://learnblockchain.cn/article/2802
 */

/**
//在compound中，要实现由ComptrollerG1升级到ComptrollerG2，其具体的升级步骤为：
function upgradeTo(address _unitroller, address _comptrollerG2) public {
    Unitroller unitroller = Unitroller(_unitroller);
    // 升级函数只有admin才能调用
    require(msg.sender == unitroller.admin());

    //admin 调用Unitroller中的_setPendingImplementation方法，将ComptrollerG2的地址填入
    unitroller._setPendingImplementation(_comtrollerG2);

    //admin 调用ComtrollerG2中的_become函数，同意成为Unitroller代理的逻辑实现合约Impl 
    ComtrollerG2(_comptrollerG2)._become(unitroller);
}

这个函数很有意思！
首先，

=====一个思考🤔
合约a-->b建立调用关系，本质上是初始化合约a中的一个变量为合约b的地址，然后在合约a中调用合约b的函数。
之前学习到的部署方式：
先部署合约b，然后部署合约a。合约a中有一个初始化函数，函数参数是合约b的地址。

我们可以反思下，合约a其实不需要构造函数。合约a只需要有一个合约b的地址变量即可。
那么，可以使用这种部署方案：
部署合约a（a中的地址变量初始化为0）和合约b，部署先后没有关系。
合约a尽管没有构造函数，但是有一个初始化函数。在初始化函数中，将合约b的地址填入合约a的地址变量中。
那么等合约a和合约b成功部署后，直接调用这个初始化函数即可。

还可以有一个进阶的部署方案：
增加一个合约c，合约c有一个upgradeTo函数，函数参数是合约a和合约b的地址（就是上面提供的函数）。
只要admin调用合约c的upgradeTo函数，就可以实现合约a调用合约b的逻辑关系。
 */

/**
Upgrading the contract is usually handled by a function that modifies the implementation contract. 
In some variants of the pattern, this function is coded into the Proxy directly, and restricted to be called only by an administrator.

This version usually also includes functions to transfer ownership of the proxy to a different address. 
Compound uses this pattern with an extra twist: 
the new implementation needs to accept the transfer, to prevent accidental upgrades to invalid contracts.
 */

/**
在compound中，要实现由ComptrollerG1升级到ComptrollerG2，其具体的升级步骤为：
admin 调用Unitroller中的_setPendingImplementation方法，将ComptrollerG2的地址填入
admin 调用ComtrollerG2中的_become函数，同意成为Unitroller代理的逻辑实现合约Impl
 */

/**
 * @title ComptrollerCore
 * @dev Storage for the comptroller is at this address, while execution is delegated to the `comptrollerImplementation`.
 * CTokens should reference this contract as their comptroller.
 */
contract Unitroller is UnitrollerAdminStorage, ComptrollerErrorReporter {

    /**
      * @notice Emitted when pendingComptrollerImplementation is changed
      */
    event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);

    /**
      * @notice Emitted when pendingComptrollerImplementation is accepted, which means comptroller implementation is updated
      */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
      * @notice Emitted when pendingAdmin is changed
      */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
      * @notice Emitted when pendingAdmin is accepted, which means admin is updated
      */
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() public {
        // Set admin to caller
        // 当前合约作为proxy contract，有一个storage address: comptrollerImplementation
        // 这个地址如果在构造函数中赋值，那么就会被写死了，不利于升级
        // 如果不是看compound源码，我自己会一直认为comptrollerImplementation必须在构造函数中赋值
        // 也正是因为没有在构造函数中赋值，所以才有了下面的_setPendingImplementation和_acceptImplementation函数
        // 这也给部署这些合约带来了便利：不必指定部署顺序。当全部部署完后，再将这些合约关联起来即可
        admin = msg.sender;
    }

    /*** Admin Functions ***/
    // 这个函数是用来做升级管理的。
    // 第一步：在_setPendingImplementation中设置即将升级的合约地址
    // 第二步：在_acceptImplementation中接受升级
    // 真是极其巧妙的设计啊！！！
    function _setPendingImplementation(address newPendingImplementation) public returns (uint) {

        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_IMPLEMENTATION_OWNER_CHECK);
        }

        address oldPendingImplementation = pendingComptrollerImplementation;

        pendingComptrollerImplementation = newPendingImplementation;

        emit NewPendingImplementation(oldPendingImplementation, pendingComptrollerImplementation);

        return uint(Error.NO_ERROR);
    }

    /**
    * @notice Accepts new implementation of comptroller. msg.sender must be pendingImplementation
    * @dev Admin function for new implementation to accept it's role as implementation
    * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
    */
    function _acceptImplementation() public returns (uint) {
        // Check caller is pendingImplementation and pendingImplementation ≠ address(0)
        if (msg.sender != pendingComptrollerImplementation || pendingComptrollerImplementation == address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK);
        }

        // Save current values for inclusion in log
        address oldImplementation = comptrollerImplementation;
        address oldPendingImplementation = pendingComptrollerImplementation;

        comptrollerImplementation = pendingComptrollerImplementation;

        pendingComptrollerImplementation = address(0);

        emit NewImplementation(oldImplementation, comptrollerImplementation);
        emit NewPendingImplementation(oldPendingImplementation, pendingComptrollerImplementation);

        return uint(Error.NO_ERROR);
    }


    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PENDING_ADMIN_OWNER_CHECK);
        }

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ACCEPT_ADMIN_PENDING_ADMIN_CHECK);
        }

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);

        return uint(Error.NO_ERROR);
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    fallback() payable external {
        // delegate all other functions to current implementation
        (bool success, ) = comptrollerImplementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize())

              switch success
              case 0 { revert(free_mem_ptr, returndatasize()) }
              default { return(free_mem_ptr, returndatasize()) }
        }
    }
}
