import { parseUnits } from '@ethersproject/units';
import { BigNumber } from 'ethers';
import { CompilationJobCreationErrorReason } from 'hardhat/types';
const { ethers, waffle } = require('hardhat');
const { expect } = require('chai');
const { deployments } = require('hardhat');

let owner;
let masterMoreContract;
let moreToken;

before(async function () {
    [owner] = await ethers.getSigners();
    await deployments.fixture(['MasterMore','MoreToken']);
    const masterMore = await deployments.get('MasterMore')
    const moretoken = await deployments.get('MoreToken')
    moreToken = new ethers.Contract(moretoken.address, moretoken.abi, owner);
    masterMoreContract = new ethers.Contract(masterMore.address, masterMore.abi, owner);
    await masterMoreContract.add(60, moreToken.address, ethers.constants.AddressZero);
});

describe('Master More deposit', function () {
  
    it('Should Deposit', async function () {
      await moreToken.approve(masterMoreContract.address, ethers.constants.MaxUint256);
      const res = await masterMoreContract.deposit(0, parseUnits('2000', 18))
      expect(res.value).to.equal(BigNumber.from(0));
    });

    it('Error when withdraw more than deposited', async function () {
      await expect(
        masterMoreContract.withdraw(0, parseUnits('2200', 18))
      ).to.be.revertedWith('withdraw: not good');
    });

    it('Should Withdraw', async function () {
      expect(
        (await masterMoreContract.withdraw(0, parseUnits('2000', 18))).value
      ).to.equal(BigNumber.from(0));
    });
  
  });
