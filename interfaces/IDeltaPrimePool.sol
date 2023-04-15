// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IDeltaPrimePool {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256);

    function borrow(uint256 _amount) external;

    function borrowIndex() external view returns (address);

    function borrowed(address) external view returns (uint256);

    function borrowersRegistry() external view returns (address);

    function checkRewards() external view returns (uint256);

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    function deposit(uint256 _amount) external;

    function depositIndex() external view returns (address);

    function getBorrowed(address _user) external view returns (uint256);

    function getBorrowingRate() external view returns (uint256);

    function getDepositRate() external view returns (uint256);

    function getMaxPoolUtilisationForBorrowing()
        external
        view
        returns (uint256);

    function getRewards() external;

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    function initialize(
        address ratesCalculator_,
        address borrowersRegistry_,
        address depositIndex_,
        address borrowIndex_,
        address tokenAddress_,
        address poolRewarder_,
        uint256 _totalSupplyCap
    ) external;

    function owner() external view returns (address);

    function poolRewarder() external view returns (address);

    function ratesCalculator() external view returns (address);

    function recoverSurplus(uint256 amount, address account) external;

    function renounceOwnership() external;

    function repay(uint256 amount) external;

    function setBorrowersRegistry(address borrowersRegistry_) external;

    function setPoolRewarder(address _poolRewarder) external;

    function setRatesCalculator(address ratesCalculator_) external;

    function setTotalSupplyCap(uint256 _newTotalSupplyCap) external;

    function tokenAddress() external view returns (address);

    function totalBorrowed() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalSupplyCap() external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function withdraw(uint256 _amount) external;
}
