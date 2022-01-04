import { task, subtask } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import * as fs from 'fs';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import { submitSources } from 'hardhat-deploy/dist/src/etherscan';
import path from 'path';
import * as types from 'hardhat/internal/core/params/argumentTypes';
import { Deployment } from 'hardhat-deploy/dist/types';
import 'hardhat-contract-sizer';
import '@nomiclabs/hardhat-solhint';
import ethernal from 'hardhat-ethernal';
import { ncp } from 'ncp';

import { TASK_NODE, TASK_TEST, TASK_NODE_GET_PROVIDER, TASK_NODE_SERVER_READY } from 'hardhat/builtin-tasks/task-names';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

// ChainIds
const MAINNET = 1;
const ROPSTEN = 3;
const RINKEBY = 4;
const GÖRLI = 5;
const KOVAN = 42;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task('custom-etherscan', 'submit contract source code to etherscan')
  .addOptionalParam('apikey', 'etherscan api key', undefined, types.string)
  .addFlag(
    'solcInput',
    'fallback on solc-input (useful when etherscan fails on the minimum sources, see https://github.com/ethereum/solidity/issues/9573)'
  )
  .setAction(async (args, hre) => {
    const keyfile = path.join(__dirname, './.etherscan-keys.json');
    const etherscanApiKey =
      args.apiKey || process.env.ETHERSCAN_API_KEY || JSON.parse(fs.readFileSync(keyfile).toString())[hre.network.name];
    if (!etherscanApiKey) {
      throw new Error(
        `No Etherscan API KEY provided. Set it through comand line option or by setting the "ETHERSCAN_API_KEY" env variable`
      );
    }

    const solcInputsPath = path.join(hre.config.paths.deployments, hre.network.name, 'solcInputs');

    await submitSources(hre, solcInputsPath, {
      etherscanApiKey,
      license: 'None',
      fallbackOnSolcInput: args.solcInput,
      forceLicense: true
    });
  });

task('list-deployments', 'List all the deployed contracts for a network', async (args, hre) => {
  console.log(`All deployments on ${hre.network.name}:`);
  for (const [name, deployment] of Object.entries(await hre.deployments.all())) {
    console.log(`${name}: ${deployment.address}`);
  }
});

async function exportAddresses(args, hre: HardhatRuntimeEnvironment) {
  let addresses: Record<string, string> = {};
  const addressesPath = path.join(__dirname, './build/addresses.json');
  if (fs.existsSync(addressesPath)) {
    addresses = JSON.parse((await fs.promises.readFile(addressesPath)).toString());
  }
  const networkAddresses = Object.entries(await hre.deployments.all()).map(
    ([name, deployRecord]: [string, Deployment]) => {
      return [name, deployRecord.address];
    }
  );
  addresses[await hre.getChainId()] = Object.fromEntries(networkAddresses);
  const stringRepresentation = JSON.stringify(addresses, null, 2);

  await fs.promises.writeFile(addressesPath, stringRepresentation);
  console.log(`Wrote ${addressesPath}. New state:`);
  console.log(addresses);

  const frontendPath = path.join(__dirname, '../frontend/src/contracts');
  const lpTokensPath = path.join(__dirname, './build/lptokens.json');
  const buildPath = path.join(__dirname, './build/artifacts');
  const farmInfoPath = path.join(__dirname, './build/farminfo.json');

  function _ncp(fromPath: string, toPath: string, options?: any) {
    return new Promise((resolve, reject) => {
      const args = [fromPath, toPath];
      if (options) {
        args.push(options);
      }
      ncp(...args, err => (err ? reject(err) : resolve(undefined)));
    });
  }

  await Promise.all([
    _ncp(addressesPath, path.join(frontendPath, './addresses.json')),
    _ncp(lpTokensPath, path.join(frontendPath, './lptokens.json')),
    _ncp(farmInfoPath, path.join(frontendPath, './farminfo.json')),
    _ncp(buildPath, path.join(frontendPath, './artifacts/'))
  ]);
}

task('export-addresses', 'Export deployment addresses to JSON file', exportAddresses);

subtask(TASK_NODE_SERVER_READY).setAction(async (args, hre, runSuper) => {
  await runSuper(args);
  await exportAddresses(args, hre);
});

task('print-network', 'Print network name', async (args, hre) => console.log(hre.network.name));

const homedir = require('os').homedir();
const privateKey = fs.readFileSync(`${homedir}/.moremoney-secret`).toString().trim();
function infuraUrl(networkName: string) {
  // return `https://eth-${networkName}.alchemyapi.io/v2/AcIJPH41nagmF3o1sPArEns8erN9N691`;
  return `https://${networkName}.infura.io/v3/ae52aea5aa2b41e287d72e10b1175491`;
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  paths: {
    artifacts: './build/artifacts'
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      blockGasLimit: 8000000,
      forking: {
        // url: infuraUrl('mainnet')
        url: 'https://api.avax.network/ext/bc/C/rpc'
      },
      // mining: {
      //   auto: false,
      //   interval: 20000
      // },
      accounts: [{ privateKey, balance: '10000168008000000000000' }]
    },
    mainnet: {
      url: infuraUrl('mainnet'),
      accounts: [privateKey]
    },
    kovan: {
      url: infuraUrl('kovan'),
      accounts: [privateKey],
      gas: 'auto',
      gasMultiplier: 1.3,
      gasPrice: 'auto'
    },
    ropsten: {
      url: infuraUrl('ropsten'),
      accounts: [privateKey]
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      accounts: [privateKey],
      blockGasLimit: 8000000
      // gasPrice: 29500000000
    },
    matic: {
      // url: 'https://rpc-mainnet.maticvigil.com/v1/b0858bc7aa27b1333df19546c12718235bd11785',
      url: 'https://sparkling-icy-breeze.matic.quiknode.pro/53a1956ec39dddb5ab61f857eed385722d8349bc/',
      // url: 'https://matic-mainnet-full-rpc.bwarelabs.com',
      accounts: [privateKey]
      // gasPrice: 1000000000
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      accounts: [privateKey]
    }
  },
  solidity: {
    version: '0.8.3',
    settings: {
      optimizer: {
        enabled: true,
        // TODO
        runs: 1
      }
    }
  },
  namedAccounts: {
    deployer: {
      default: 0
    },
    curveFactory: {
      43114: '0xb17b674D9c5CB2e441F8e196a2f048A81355d031',
      31337: '0xb17b674D9c5CB2e441F8e196a2f048A81355d031'
    },
    curveMetaPoolBase: {
      43114: '0x7f90122bf0700f9e7e1f688fe926940e8839f353',
      31337: '0x7f90122bf0700f9e7e1f688fe926940e8839f353'
    },
    curveZap: {
      43114: '0x001E3BA199B4FF4B5B6e97aCD96daFC0E2e4156e',
      31337: '0x001E3BA199B4FF4B5B6e97aCD96daFC0E2e4156e'
    },
    baseCurrency: {
      31337: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      //31337: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      1: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      42: '0xd0a1e359811322d97991e03f863a0c30c2cf029c',
      '43114': '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
      137: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
      56: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c'
    },
    dai: {
      1: '0x6b175474e89094c44da98b954eedeac495271d0f',
      31337: '0x6b175474e89094c44da98b954eedeac495271d0f',
      42: '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
      default: '0x6b175474e89094c44da98b954eedeac495271d0f'
    },
    usdc: {
      default: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
    },
    usdt: {
      1: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      31337: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      //31337: '0xde3A24028580884448a5397872046a019649b084',
      '43114': '0xde3A24028580884448a5397872046a019649b084',
      137: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      56: '0x55d398326f99059ff775485246999027b3197955'
    },
    amm1Router: {
      31337: '0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106',
      43114: '0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106'
    },
    amm2Router: {
      31337: '0x60aE616a2155Ee3d9A68541Ba4544862310933d4',
      43114: '0x60aE616a2155Ee3d9A68541Ba4544862310933d4'
    }
  }
};
