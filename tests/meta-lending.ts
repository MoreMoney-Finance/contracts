const { expect } = require("chai");
const { ethers } = require("hardhat");
import StableLending2 from '../build/artifacts/contracts/StableLending2.sol/StableLending2.json';
import { useAddresses } from './addresses';
import { loadKey } from './load-key';

const { signer } = loadKey();

const StableLending2Contract = new ethers.Contract(
  useAddresses().StableLending2,
  StableLending2.abi,
  signer
);

describe("Smol PP", function () {

  it("should have NFT URI", async function () {
    const res = await StableLending2Contract.tokenURI(100000002);
    console.log(res);
  });

});    