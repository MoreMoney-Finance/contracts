import { parseUnits } from '@ethersproject/units';
import { BigNumber } from 'ethers';
const { ethers, waffle } = require('hardhat');
const { expect } = require('chai');

let owner;
let masterMoreContract;
let moreToken;
const provider = waffle.provider;


beforeEach(async function () {
    const MasterMore = await ethers.getContractFactory(
      'MasterMore'
    );
    const MoreToken = await ethers.getContractFactory(
        'MoreToken'
    );
    [owner] = await ethers.getSigners();
    masterMoreContract = await MasterMore.connect(owner).deploy();
    moreToken = await MoreToken.connect(owner).deploy(1000000000);
});

describe('Master More deposit', function () {
  
    it('Deposit', async function () {
        
      await moreToken.approve(masterMoreContract.address, ethers.constants.MaxUint256);
    //   const res = await masterMoreContract.deposit(1, parseUnits('2000', 18));
    const res = await masterMoreContract.poolInfo();
      console.log(res);
      expect(
        (await masterMoreContract.connect(owner).deposit('2000', 18)).value
      ).to.equal(BigNumber.from(0));
    });
  
  });
