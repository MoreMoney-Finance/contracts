import { ethers } from "hardhat";
import { Signer } from "ethers";
import { expect } from "chai";
import { impersonateOwner } from "../deploy/Roles";
import * as fs from 'fs';

describe("NFTContract", function () {
    const homedir = require('os').homedir();
const privateKey = fs.readFileSync(`${homedir}/.moremoney-secret`).toString().trim();
  let nftContract;
  let owner: Signer;
  let minter: Signer;
  const signedTypes = {
    MintData: [
      {
        name: 'minter',
        type: 'address'
      },
      {
        name: 'epoch',
        type: 'uint256'
      }
    ]
  };

  beforeEach(async function () {
    console.log('beforeEach');

    [owner, minter] = await ethers.getSigners();
    console.log('owner', await owner.getAddress())
    console.log('minter', await minter.getAddress())
    const Roles = await ethers.getContractFactory("Roles"); // Make sure to deploy the Roles contract first

    // Deploy the Roles contract
    const roles = await Roles.connect(owner).deploy(owner.getAddress());
    await roles.deployed();

    const NFTContract = await ethers.getContractFactory("NFTContract");

    // Deploy the NFTContract with the Roles contract address and slotsPerEpoch value
    nftContract = await NFTContract.connect(owner).deploy(roles.address, 10);
    await nftContract.deployed();

    // Get the owner and minter signers
  });

  it("should mint a new NFT", async function () {

    const mintData = {
      minter: await minter.getAddress(),
      epoch: 1,
    };
    // Sign the mint data
    // const signature = await owner.signMessage(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch])));
    const message = ethers.utils.solidityKeccak256(
        ["string", "address", "uint256"],
        ["MintData(address minter,uint256 epoch)", mintData.minter, mintData.epoch]
      );
      const signature = await minter.signMessage(message);
    // Mint a new NFT
    await expect(nftContract.connect(minter).mintNFT(mintData, signature))
      .to.emit(nftContract, "Transfer")
      .withArgs(ethers.constants.AddressZero, await minter.getAddress(), 1);

    // Check the mint data for the NFT
    const tokenId = 1;
    const tokenMintData = await nftContract.viewMintData(tokenId);
    expect(tokenMintData.minter).to.equal(await minter.getAddress());
    expect(tokenMintData.epoch).to.equal(1);
  });

  it("should not mint if the epoch is invalid", async function () {
    const mintData = {
      minter: await minter.getAddress(),
      epoch: 2, // Invalid epoch
    };

    // Sign the mint data
    const signature = await owner.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch]))));

    // Attempt to mint a new NFT
    await expect(nftContract.connect(minter).mintNFT(mintData, signature)).to.be.revertedWith("Invalid epoch for minting");
  });

  it("should not mint if all slots for the current epoch are filled", async function () {
    // Mint NFTs to fill all slots for the current epoch
    for (let i = 0; i < 10; i++) {
      const mintData = {
        minter: await minter.getAddress(),
        epoch: 1,
      };

      // Sign the mint data
      const signature = await owner.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch]))));

      // Mint a new NFT
      await nftContract.connect(minter).mintNFT(mintData, signature);
    }

    // Attempt to mint a new NFT
    const mintData = {
      minter: await minter.getAddress(),
      epoch: 1,
    };

    // Sign the mint data
    const signature = await owner.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch]))));

    await expect(nftContract.connect(minter).mintNFT(mintData, signature)).to.be.revertedWith(
      "All slots for the current epoch have been filled"
    );
  });

  // Add more test cases as needed
});
