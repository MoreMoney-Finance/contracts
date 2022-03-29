// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import './IVeERC20.sol';

/**
 * @dev Interface of the VeMore 
 */
interface IVeMore is IVeERC20, IERC721Receiver {
    function isUser(address _addr) external view returns (bool);

    function deposit(uint256 _amount) external;

    function claim() external;

    function withdraw(uint256 _amount) external;

    function unstakeNft() external;

    function getStakedNft(address _addr) external view  returns (uint256);

    function getStakedPtp(address _addr) external view returns (uint256);

    function getVotes(address _account) external view returns (uint256);
}