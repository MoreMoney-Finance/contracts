const { expect } = require("chai");
const { ethers } = require("hardhat");
import { BigNumber } from 'ethers';
import { useAddresses } from './addresses';
import { loadKey } from './load-key';
import VeMoreStaking from '../build/artifacts/contracts/governance/VeMoreStaking.sol/VeMoreStaking.json';
import VeMoreToken from '../build/artifacts/contracts/governance/VeMoreToken.sol/VeMoreToken.json';
import MoreToken from '../build/artifacts/contracts/governance/MoreToken.sol/MoreToken.json';
import { formatEther, parseEther, parseUnits } from 'ethers/lib/utils';

const { signer } = loadKey();
const sAmount = parseUnits('100', 18);

const MoreTokenContract = new ethers.Contract(
  useAddresses().MoreToken,
  MoreToken.abi,
  signer
);
const vMoreContract = new ethers.Contract(
  useAddresses().VeMoreStaking,
  VeMoreStaking.abi,
  signer
);

describe("vMore Staking", function () {

  it("Should deposit", async function () {
    await MoreTokenContract.approve(
      useAddresses().VeMoreStaking,
      ethers.constants.MaxUint256
    );
    const res = await vMoreContract.deposit(sAmount);
    expect(res.value).to.equal(BigNumber.from("0"));
  });

  it("Staked More should be equal to deposit", async function () {
    const res = await vMoreContract.getStakedMore(signer.address);
    expect(res).to.equal(sAmount);
  });

  it("Withdraw the same amount", async function () {
    const res = await vMoreContract.withdraw(sAmount);
    expect(res.value).to.equal(BigNumber.from("0"));
  });
  
  it("Staked More should be 0 after withdraw", async function (){
    const res = await vMoreContract.getStakedMore(signer.address);
    expect(res).to.equal(BigNumber.from("0"));
  });
});