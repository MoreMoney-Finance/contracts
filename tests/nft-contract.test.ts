import { expect } from "chai";
import { ethers } from "hardhat";

describe("NFTContract", function () {
  let nftContract;

  beforeEach(async function () {
    console.log('beforeEach');

    const [owner, minter, newSigner] = await ethers.getSigners();
    const Roles = await ethers.getContractFactory("Roles");

    const roles = await Roles.connect(owner).deploy(owner.getAddress());
    await roles.deployed();

    const NFTContract = await ethers.getContractFactory("NFTContract");

    // Update the constructor to include the new signer
    nftContract = await NFTContract.connect(owner).deploy(roles.address, 10, newSigner.getAddress());
    await nftContract.deployed();
    await nftContract.connect(owner).setSigner(await newSigner.getAddress());
  });

  it("should mint a new NFT", async function () {
    const [owner, minter, newSigner] = await ethers.getSigners();

    const domain = {
      name: "MMNFT",
      version: "1",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: nftContract.address,
    };

    const types = {
      MintData: [
        { name: "minter", type: "address" },
        { name: "epoch", type: "uint256" },
      ],
    };

    const mintData = {
      minter: await minter.getAddress(),
      epoch: 1,
    };

    // Use the new signer to sign the mint data
    const signature = await newSigner._signTypedData(domain, types, mintData);

    await expect(nftContract.connect(minter).mintNFT(mintData, signature))
      .to.emit(nftContract, "Transfer")
      .withArgs(ethers.constants.AddressZero, await minter.getAddress(), 1);

    const tokenId = 1;
    const tokenMintData = await nftContract.viewMintData(tokenId);
    expect(tokenMintData.minter).to.equal(await minter.getAddress());
    expect(tokenMintData.epoch).to.equal(1);
  });

  it("should not mint if the epoch is invalid", async function () {
    const [owner, minter, newSigner] = await ethers.getSigners();
    const mintData = {
      minter: await minter.getAddress(),
      epoch: 2, // Invalid epoch
    };

    // Sign the mint data with the new signer
    const signature = await newSigner.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch]))));

    // Attempt to mint a new NFT
    await expect(nftContract.connect(minter).mintNFT(mintData, signature)).to.be.revertedWith("Invalid epoch for minting");
  });

  it("should not mint if all slots for the current epoch are filled", async function () {
    const [owner, minter, newSigner, minter1, minter2, minter3, minter4, minter5, minter6, minter7, minter8, minter9, minter10] = await ethers.getSigners();

    // Mint NFTs to fill all slots for the current epoch
    for (let i = 0; i < 10; i++) {
      const randomMinter = [minter1, minter2, minter3, minter4, minter5, minter6, minter7, minter8, minter9, minter10][i];
      const domain = {
        name: "MMNFT",
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: nftContract.address,
      };

      const types = {
        MintData: [
          { name: "minter", type: "address" },
          { name: "epoch", type: "uint256" },
        ],
      };

      const mintData = {
        minter: await randomMinter.getAddress(),
        epoch: 1,
      };

      // Use the new signer to sign the mint data
      const signature = await newSigner._signTypedData(domain, types, mintData);

      // Mint a new NFT
      await nftContract.connect(randomMinter).mintNFT(mintData, signature);
    }

    // Attempt to mint a new NFT
    const mintData = {
      minter: await minter.getAddress(),
      epoch: 1,
    };

    // Sign the mint data with the new signer
    const signature = await newSigner.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [mintData.minter, mintData.epoch]))));

    await expect(nftContract.connect(minter).mintNFT(mintData, signature)).to.be.revertedWith("Invalid epoch for minting");

    // Change the epoch because now the epoch is full
    const mintDataNewEpoch = {
      minter: await minter.getAddress(),
      epoch: 2,
    };

    const domain = {
      name: "MMNFT",
      version: "1",
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: nftContract.address,
    };

    const types = {
      MintData: [
        { name: "minter", type: "address" },
        { name: "epoch", type: "uint256" },
      ],
    };

    const signatureNewEpoch = await newSigner._signTypedData(domain, types, mintDataNewEpoch);

    await expect(nftContract.connect(minter).mintNFT(mintDataNewEpoch, signatureNewEpoch))
      .to.emit(nftContract, "Transfer")
      .withArgs(ethers.constants.AddressZero, await minter.getAddress(), 11);
  });

  // Add more test cases as needed
});
