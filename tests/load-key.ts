import * as fs from 'fs';
import { ethers } from 'ethers';

export function loadKey() {
  const provider = new ethers.providers.JsonRpcProvider(
    'http://localhost:8545'
  );

  const homedir = require('os').homedir();

  const privateKey = fs
    // .readFileSync(`${homedir}/.test-contracts`)
    .readFileSync(`${homedir}/.moremoney-secret`)
    .toString()
    .trim();

  const signer = new ethers.Wallet(privateKey, provider);
  return { signer, provider };
}
