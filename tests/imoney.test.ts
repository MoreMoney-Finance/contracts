const { expect } = require("chai");
const { ethers } = require("hardhat");
import { BigNumber } from 'ethers';
import { parseUnits } from 'ethers/lib/utils';
import StableLending2InterestForwarder from '../build/artifacts/contracts/rewards/StableLending2InterestForwarder.sol/StableLending2InterestForwarder.json';
import Stablecoin from '../build/artifacts/contracts/Stablecoin.sol/Stablecoin.json';
import WrapNativeStableLending2 from '../build/artifacts/contracts/WrapNativeStableLending2.sol/WrapNativeStableLending2.json';
import { useAddresses } from './addresses';
import { loadKey } from './load-key';

const { signer } = loadKey();
const sAmount = parseUnits('100', 18);

const strategyAddress = useAddresses().YieldYakAVAXStrategy2;

const StablecoinContract = new ethers.Contract(
  useAddresses().Stablecoin,
  Stablecoin.abi,
  signer
);

const StableLending2InterestForwarderContract = new ethers.Contract(
  useAddresses().StableLending2InterestForwarder,
  StableLending2InterestForwarder.abi,
  signer
);

const nativeDepositBorrowContract  = new ethers.Contract(
  useAddresses().WrapNativeStableLending2,
  WrapNativeStableLending2.abi,
  signer
);

describe("iMoney Staking", function () {

  it("Borrow Money first", async function () {
    const collateralAmount = "50"
    const cAmount = parseUnits(
      collateralAmount.toString(),
      18
    );
    const res = await nativeDepositBorrowContract.mintDepositAndBorrow(strategyAddress, sAmount, signer.address, {value: cAmount});
    expect(res.value).to.equal(cAmount);
  });

  it("Should deposit", async function () {
    await StablecoinContract.approve(
      useAddresses().StableLending2InterestForwarder,
      ethers.constants.MaxUint256
    );
    const res = await StableLending2InterestForwarderContract.deposit(sAmount);
    expect(res.value).to.equal(BigNumber.from("0"));
  });

  it("Staked Money should be equal to deposit", async function () {
    const res = await StableLending2InterestForwarderContract.balanceOf(
      signer.address
    );
    expect(res).to.equal(sAmount);
  });

  it("Withdraw the same amount", async function () {
    const res = await StableLending2InterestForwarderContract.withdraw(sAmount);
    expect(res.value).to.equal(BigNumber.from("0"));
  });
  
  it("Staked Money should be 0 after withdraw", async function (){
    const res = await StableLending2InterestForwarderContract.viewPendingReward(signer.address)
    expect(res).to.equal(BigNumber.from("0"));
  });
});    