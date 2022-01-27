pragma solidity ^0.8.0;

interface IMaxiStaking {
    function MAXI() external view returns (address);

    function claim(address _recipient) external;

    function contractBalance() external view returns (uint256);

    function distributor() external view returns (address);

    function epoch()
        external
        view
        returns (
            uint256 number,
            uint256 distribute,
            uint32 length,
            uint32 endTime
        );

    function forfeit() external;

    function giveLockBonus(uint256 _amount) external;

    function index() external view returns (uint256);

    function locker() external view returns (address);

    function manager() external view returns (address);

    function pullManagement() external;

    function pushManagement(address newOwner_) external;

    function rebase() external;

    function renounceManagement() external;

    function returnLockBonus(uint256 _amount) external;

    function sMAXI() external view returns (address);

    function setContract(uint8 _contract, address _address) external;

    function setWarmup(uint256 _warmupPeriod) external;

    function stake(uint256 _amount, address _recipient) external returns (bool);

    function toggleDepositLock() external;

    function totalBonus() external view returns (uint256);

    function unstake(uint256 _amount, bool _trigger) external;

    function warmupContract() external view returns (address);

    function warmupInfo(address)
        external
        view
        returns (
            uint256 deposit,
            uint256 gons,
            uint256 expiry,
            bool lock
        );

    function warmupPeriod() external view returns (uint256);
}
