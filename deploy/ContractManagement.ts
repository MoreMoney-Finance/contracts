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

  const { manage, replace, strategies } = contractMigrations[network.name];
  let filteredManage: string[] = Array.from(
    new Set<string>(manage.filter(toManage => !alreadyManaged.includes(toManage.toLowerCase())) as string[])
  );
  const filteredReplace: Record<string, string> = Object.fromEntries(
    Object.entries(replace).filter(
      ([toManage, toDisable]) =>
        !alreadyManaged.includes(toManage.toLowerCase()) || alreadyManaged.includes((toDisable as string).toLowerCase())
    )
  ) as Record<string, string>;
  let filteredStrategies: Set<string> = new Set(
    strategies.filter(strat => !alreadyEnabled.includes(strat.toLowerCase()))
  );

  while (filteredManage.length > 0 || Object.keys(filteredReplace).length > 0 || filteredStrategies.size > 0) {
    const total = filteredManage.length + Object.keys(filteredReplace).length * 2;

    let toManage: string[] = [];
    const toDisable: string[] = [];
    let toStrategize: string[] = [];
    toManage = filteredManage.slice(0, 8);
    filteredManage = filteredManage.slice(toManage.length, filteredManage.length);

    const replacers = Object.keys(filteredReplace);
    for (let i = 0; replacers.length > i && 8 >= toManage.length + toDisable.length + 2; i++) {
      toManage.push(replacers[i]);
      toDisable.push(filteredReplace[replacers[i]]);
      delete filteredReplace[replacers[i]];
    }

    if (filteredManage.length === 0 && Object.keys(filteredReplace).length === 0) {
      toStrategize = Array.from(filteredStrategies);
      filteredStrategies = new Set([]);
    }

    console.log({ toManage, toDisable, toStrategize });
    const ContractManagement = await deploy('ContractManagement', {
      from: deployer,
      args: [toManage, toDisable, toStrategize, roles.address],
      log: true,
      skipIfAlreadyDeployed: false
    });

    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('ContractManagement:');
    console.log(`Call ${dC.address} . execute ( ${ContractManagement.address} )`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();

    if (network.name === 'localhost') {
      const Roles = await ethers.getContractAt('Roles', roles.address);
      const currentOwner = await Roles.owner();

      console.log(`deployer is: ${deployer}`);
      console.log(`owner of roles is: ${currentOwner}`);

      if (getAddress(currentOwner) !== getAddress(deployer) && (await getChainId()) === '31337') {
        console.log('Impersonating owner');

        let tx = await (await ethers.getSigner(deployer)).sendTransaction({ to: currentOwner, value: parseEther('5') });
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
  const trancheIDService = await ethers.getContractAt(
    'TrancheIDService',
    (
      await deployments.get('TrancheIDService')
    ).address
  );
  const StableLending = await deployments.get('StableLending');
  if (!(await trancheIDService.viewSlotByTrancheContract(StableLending.address)).gt(0)) {
    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('Tranche slot:');
    console.log(`Call ${StableLending.address} . setupTrancheSlot()`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();

    if (network.name === 'localhost') {
      const Roles = await ethers.getContractAt('Roles', roles.address);
      const currentOwner = await Roles.owner();

      const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
      await provider.send('hardhat_impersonateAccount', [currentOwner]);
      const signer = provider.getSigner(currentOwner);

      const tx = await (await ethers.getContractAt('StableLending', StableLending.address))
        .connect(signer)
        .setupTrancheSlot();
      console.log(`Setting up tranche slot for isolated lending: ${tx.hash}`);
      await tx.wait();
    }
  }

  // const tx = await (await ethers.getContractAt('CurvePoolSL', (await deployments.get('CurvePoolSL')).address)).rebalance();
  // console.log(`rebalancing: ${tx.hash}`);
  // await tx.wait();
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

  const { manage, replace, strategies } = contractMigrations[network.name];
  const filteredManage = manage.filter(toManage => !alreadyManaged.includes(toManage.toLowerCase()));
  const filteredReplace = Object.fromEntries(
    Object.entries(replace).filter(
      ([toManage, toDisable]) =>
        !alreadyManaged.includes(toManage.toLowerCase()) || alreadyManaged.includes((toDisable as string).toLowerCase())
    )
  );

  if (!alreadyManaged.includes(contractAddress.toLowerCase())) {
    const chainId = await getChainId();
    const chainAddresses = addresses[chainId];
    if (network.name !== 'hardhat' && contractName in chainAddresses && alreadyManaged.includes(chainAddresses[contractName].toLowerCase())) {
      if (network.name !== 'hardhat') {
        contractMigrations[network.name] = {
          manage: filteredManage,
          replace: { [contractAddress]: chainAddresses[contractName], ...filteredReplace },
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
          replace: filteredReplace,
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
      const { manage, replace, strategies } = contractMigrations[network.name];
      const filteredStrategies = strategies.filter(strat => !alreadyEnabled.includes(strat.toLowerCase()));
      contractMigrations[network.name] = {
        manage,
        replace,
        strategies: Array.from(new Set([strategyAddress, ...filteredStrategies]))
      };

      const contractMigrationsPath = path.join(__dirname, '../data/contract-migrations.json');
      await fs.promises.writeFile(contractMigrationsPath, JSON.stringify(contractMigrations, null, 2));
    }
  }
}
