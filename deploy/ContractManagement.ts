import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';
import { ethers, getChainId, network } from 'hardhat';

import contractMigrations from '../data/contract-migrations.json';
import * as addresses from '../build/addresses.json';
import * as fs from 'fs';
import path from 'path';
import { getAddress } from '@ethersproject/address';
import { parseEther } from '@ethersproject/units';

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

  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const alreadyManaged = (await dC.allManagedContracts()).map(a => a.toLowerCase());
  const registry = await ethers.getContractAt('StrategyRegistry', (await deployments.get('StrategyRegistry')).address);
  const alreadyEnabled = (await registry.allEnabledStrategies()).map(a => a.toLowerCase());
  

  const { manage, disable, strategies } = contractMigrations[network.name];
  const filteredManage = manage.filter(toManage => !alreadyManaged.includes(toManage.toLowerCase()));
  const filteredDisable = disable.filter(toDisable => alreadyManaged.includes(toDisable.toLowerCase()));
  const filteredStrategies = strategies.filter((strat) => !alreadyEnabled.includes(strat.toLowerCase()));

  if (filteredManage.length > 0 || filteredDisable.length > 0 || filteredStrategies.length > 0) {
    const ContractManagement = await deploy('ContractManagement', {
      from: deployer,
      args: [filteredManage, filteredDisable, filteredStrategies, roles.address],
      log: true,
      skipIfAlreadyDeployed: false
    });

    console.log();
    console.log('ContractManagement:');
    console.log(`Call ${dC.address} . execute ( ${ContractManagement.address} )`);
    console.log();

    if (network.name === 'localhost') {
      const Roles = await ethers.getContractAt('Roles', roles.address);
      const currentOwner = await Roles.owner();

      console.log(`deployer is: ${deployer}`);
      console.log(`owner of roles is: ${currentOwner}`);

      if (getAddress(currentOwner) !== getAddress(deployer) && (await getChainId()) === '31337') {
        console.log('Impersonating owner');

        let tx = await (await ethers.getSigner(deployer)).sendTransaction({ to: currentOwner, value: parseEther('1') });
        await tx.wait();

        const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
        await provider.send('hardhat_impersonateAccount', [currentOwner]);
        const signer = provider.getSigner(currentOwner);

        if ((await ethers.provider.getCode(ContractManagement.address)) !== '0x') {
          tx = await dC.connect(signer).executeAsOwner(ContractManagement.address);
          console.log(`Running contract management: ${tx.hash}`);
          await tx.wait();
        }
      }
    }
  }
};
deploy.tags = ['ContractManagement', 'base'];
deploy.dependencies = ['DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;

export async function manage(deployments: DeploymentsExtension, contractAddress: string, contractName): Promise<void> {
  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const alreadyManaged = (await dC.allManagedContracts()).map(a => a.toLowerCase());

  const { manage, disable, strategies } = contractMigrations[network.name];
  const filteredManage = manage.filter(toManage => !alreadyManaged.includes(toManage.toLowerCase()));
  const filteredDisable = disable.filter(toDisable => alreadyManaged.includes(toDisable.toLowerCase()));

  if (!alreadyManaged.includes(contractAddress.toLowerCase())) {
    const chainId = await getChainId();
    const chainAddresses = addresses[chainId];
    if (
      contractName in chainAddresses &&
      alreadyManaged.includes(chainAddresses[contractName].toLowerCase())
    ) {
      if (network.name !== 'hardhat') {
        contractMigrations[network.name] = {
          manage: Array.from(new Set([contractAddress, ...filteredManage])),
          disable: Array.from(new Set([chainAddresses[contractName], ...filteredDisable])),
          strategies
        };
      } else {
        const tx = await dC.replaceContract(chainAddresses[contractName], contractAddress, { gasLimit: 8000000 });
        console.log(
          `dependencyController.replaceContract(${contractName} replacing ${chainAddresses[contractName]} for ${contractAddress}) tx: ${tx.hash}`
        );
        await tx.wait();
      }
    } else {
      if (network.name !== 'hardhat') {
        contractMigrations[network.name] = {
          manage: Array.from(new Set([contractAddress, ...filteredManage])),
          disable: filteredDisable,
          strategies
        };  
      } else {
        const tx = await dC.manageContract(contractAddress, { gasLimit: 8000000 });
        console.log(`dependencyController.manageContract(${contractName} at ${contractAddress}) tx: ${tx.hash}`);
        await tx.wait();
      }
    }

    const contractMigrationsPath = path.join(__dirname, '../data/contract-migrations.json');
    await fs.promises.writeFile(contractMigrationsPath, JSON.stringify(contractMigrations, null, 2));
  }
}

export async function registerStrategy(deployments: DeploymentsExtension, strategyAddress: string): Promise<void> {
  const registry = await ethers.getContractAt('StrategyRegistry', (await deployments.get('StrategyRegistry')).address);
  const alreadyEnabled = (await registry.allEnabledStrategies()).map(a => a.toLowerCase());
  if (!alreadyEnabled.includes(strategyAddress.toLowerCase())) {
    if (network.name === 'hardhat') {
      const tx = await registry.enableStrategy(strategyAddress);
      console.log(`Enabling strategy at ${strategyAddress} with tx: ${tx.hash}`);
      await tx.wait();
    } else {
      const { manage, disable, strategies } = contractMigrations[network.name];
      const filteredStrategies = strategies.filter((strat) => !alreadyEnabled.includes(strat.toLowerCase()));
      contractMigrations[network.name] = {
          manage,
          disable,
          strategies: Array.from(new Set([strategyAddress, ...filteredStrategies]))
      }
  
  
      const contractMigrationsPath = path.join(__dirname, '../data/contract-migrations.json');
      await fs.promises.writeFile(contractMigrationsPath, JSON.stringify(contractMigrations, null, 2));
  
    }
  }
}
