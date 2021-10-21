// iterate over, group them up
// test their parameters all over the place?
// perhaps another central registry? -- to make idempotency easier

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { BigNumber } from '@ethersproject/bignumber';
import { parseUnits } from '@ethersproject/units';
const { ethers } = require('hardhat');


const baseCurrency = {
    kovan: 'WETH',
    mainnet: 'WETH',
    avalanche: 'WAVAX',
    localhost: 'WETH',
    matic: 'WETH',
    bsc: 'WBNB'
};
const tokensPerNetwork: Record<string, Record<string, string>> ={
    localhost: {
      WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      ETH: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
      // PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
      // USDT: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
      // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
      // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
      // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
      // JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
      // USDC: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664',
      // DAI: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
      // WBTC: '0x50b7545627a5162f82a992c33b87adc75187b218'  
    },
    avalanche: {
      WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      ETH: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
      // PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
      // USDT: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
      // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
      // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
      // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
      // JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
      // USDC: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664',
      // DAI: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
      // WBTC: '0x50b7545627a5162f82a992c33b87adc75187b218'  
    }
};

export type TokenInitRecord = {
    decimals?: number;
    oracle: string;
    debtCeiling: number;
    mintingFeePercent?: number;
    colRatioPercent?: number;
};

const tokenInitRecords: Record<string, TokenInitRecord> = {
  WAVAX: {
    oracle: 'ChainlinkOracle',
    debtCeiling: 1000,
  },
  ETH: {
    oracle: 'ChainlinkOracle',
    debtCeiling: 1000
  },
};

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);
  
  const targetTokens: string[] = []
  const debtCeilings: BigNumber[] = [];
  const oracles: string[] = [];
  const feesPerMil: BigNumber[] = [];
  const colRatios: BigNumber[] = [];

  const IL = await ethers.getContractAt('IsolatedLending', (await deployments.get('IsolatedLending')).address);

  for (const [tokenName, tokenAddress] of Object.entries(tokensPerNetwork[network.name])) {
    const initRecord = tokenInitRecords[tokenName];
    const debtCeiling = parseUnits(initRecord.debtCeiling.toString(), 6);
    const mintingFee = BigNumber.from(((initRecord.mintingFeePercent ?? 1) * 10).toString());
    const colRatio = BigNumber.from(((initRecord.colRatioPercent ?? 166) * 100).toString());

    const [ilDebtCeiling, ilTotalDebt, ilFeePerMil, ilStabilityFee, ilMintingFee, ilColRatio] = await IL.viewILMetadata(tokenAddress);
    if (!(debtCeiling.eq(ilDebtCeiling) && mintingFee.eq(ilMintingFee) && colRatio.eq(ilColRatio))) {
        targetTokens.push(tokenAddress);
        debtCeilings.push(debtCeiling);
        oracles.push((await deployments.get(initRecord.oracle)).address);
        feesPerMil.push(mintingFee);
        colRatios.push(colRatio);
    }
  }
  const args = [targetTokens, debtCeilings, feesPerMil, colRatios, oracles, roles.address];

  const TokenActivation = await deploy('TokenActivation', {
    from: deployer,
    args,
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });

  const dC = await ethers.getContractAt('DependencyController', await deployments.get('DependencyController'));
  const tx = await dC.execute(TokenActivation.address);
  console.log(`Executing token activation: ${tx.hash}`);
};

deploy.tags = ['TokenActivation', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
