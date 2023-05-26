import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { NFTContract } from "../typechain/contracts/NFTContract";
import { useAddresses } from "./addresses";
import WrapNativeStableLending2 from '../build/artifacts/contracts/WrapNativeStableLending2.sol/WrapNativeStableLending2.json';
import { loadKey } from './load-key';
import { parseUnits } from "@ethersproject/units";

const { signer } = loadKey();
const sAmount = parseUnits('100', 18);

const nativeDepositBorrowContract  = new ethers.Contract(
    useAddresses().WrapNativeStableLending2,
    WrapNativeStableLending2.abi,
    signer
  );
  const strategyAddress = useAddresses().YieldYakAVAXStrategy2; 

describe("NFTContract", () => {
  let nftContract: NFTContract;
  let owner: Signer;
  let alice: Signer;
  let bob: Signer;

  const INITIAL_LIMIT = 100;
  const LIMIT_DOUBLING_PERIOD = 10 * 24 * 60 * 60; // 10 days
  const MINIMUM_DEBT = 100;
    
  //NFTContract: 0xBaa04398A780fc56EaAea15ebd11edD25A2A26AA
  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();

    const NFTContract = await ethers.getContractFactory("NFTContract");
    const MetaLending = await ethers.getContractFactory("MetaLending");
    const Roles = await ethers.getContractFactory("Roles");
    const roles = (await Roles.deploy(await owner.getAddress()));
    await roles.deployed();
    console.log('roles deployed', roles.address);
    const metaLending = (await MetaLending.connect(owner).deploy(roles.address));
    await metaLending.deployed();
    console.log('metaLending deployed');
    const metaLendingAddress = metaLending.address;
    console.log('deployed');
    nftContract = (await NFTContract.deploy(roles.address, metaLendingAddress)) as NFTContract;
    
    await nftContract.deployed();

    
  });

  it("should not allow owner to claim NFTs if limit is reached", async () => {
    // Mint NFTs to reach the limit
    for (let i = 0; i < INITIAL_LIMIT; i++) {
      await nftContract.connect(owner).claimNFT();
    }

    // Try to mint one more NFT
    await expect(nftContract.connect(owner).claimNFT()).to.be.revertedWith("NFT limit reached");
  });

   it("should allow claiming NFTs under the specified conditions", async () => {
    // Mint NFTs to reach the limit
    for (let i = 0; i < INITIAL_LIMIT; i++) {
      await nftContract.connect(owner).claimNFT();
    }

    // Check if the NFT limit has been reached
    expect(await nftContract.totalSupply()).to.equal(INITIAL_LIMIT);

    // Check if a user with enough debt can claim an NFT
    const aliceDebt = 200;
    const cAmount = parseUnits(
        aliceDebt.toString(),
      18
    );
    // await nftContract.connect(owner).setDebtLimit(alice.getAddress(), aliceDebt);
    const res = await nativeDepositBorrowContract.connect(alice).mintDepositAndBorrow(strategyAddress, sAmount, alice.getAddress(), {value: cAmount});

    await nftContract.connect(alice).claimNFT();
    expect(await nftContract.totalSupply()).to.equal(INITIAL_LIMIT + 1);
    expect(await nftContract.ownerOf(INITIAL_LIMIT + 1)).to.equal(alice.getAddress());

    // Check if a user with insufficient debt cannot claim an NFT
    const bobDebt = 200;
    const cAmountBob = parseUnits(
        bobDebt.toString(),
      18
    );
    // await nftContract.connect(owner).setDebtLimit(alice.getAddress(), aliceDebt);
    const resBob = await nativeDepositBorrowContract.connect(bob).mintDepositAndBorrow(strategyAddress, sAmount, bob.getAddress(), {value: cAmountBob});
    
    await expect(nftContract.connect(bob).claimNFT()).to.be.revertedWith("Not enough debt");
    expect(await nftContract.totalSupply()).to.equal(INITIAL_LIMIT + 1);
  });

});

