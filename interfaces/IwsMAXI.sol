pragma solidity ^0.8.0;

interface IwsMAXI {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function baseIndex() external view returns (uint256);

    function checkpoints(address, uint256)
        external
        view
        returns (uint256 fromBlock, uint256 votes);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function delegate(address delegatee) external;

    function delegates(address) external view returns (address);

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function index() external view returns (uint256);

    function indexNormalized() external view returns (uint256);

    function name() external view returns (string memory);

    function numCheckpoints(address) external view returns (uint256);

    function sMAXI() external view returns (address);

    function sMAXITowsMAXI(uint256 _amount) external view returns (uint256);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function unwrap(uint256 _amount) external returns (uint256);

    function wrap(uint256 _amount) external returns (uint256);

    function wsMAXITosMAXI(uint256 _amount) external view returns (uint256);
}
