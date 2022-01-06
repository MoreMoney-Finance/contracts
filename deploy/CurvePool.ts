import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { artifacts, ethers } from 'hardhat';
import ICurvePool from '../build/artifacts/interfaces/ICurvePool.sol/ICurvePool.json';
import ICurveFactory from '../build/artifacts/interfaces/ICurveFactory.sol/ICurveFactory.json';
import { assignMainCharacter, CURVE_POOL } from './DependencyController';
import path from 'path';
import * as fs from 'fs';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { save, execute } = deployments;
  const { curveFactory, curveMetaPoolBase } = await getNamedAccounts();

  const existing = await deployments.getOrNull('CurvePool');
  if (!existing) {
    const curveFactoryContract = await ethers.getContractAt('ICurveFactory', curveFactory);

    const stable = await deployments.get('Stablecoin');

    const args = [curveMetaPoolBase, 'MoreMoney USD', 'MONEY', stable.address, 200, 4000000];

    const deploy_metapool = 'deploy_metapool(address,string,string,address,uint256,uint256)';
    const poolCount = (await curveFactoryContract.pool_count()).toNumber();
    const tx = await curveFactoryContract.functions[deploy_metapool](...args);
    console.log(`Deploying lending pool via ${tx.hash}`);
    await tx.wait();

    const newPoolCount = (await curveFactoryContract.pool_count()).toNumber();
    if (newPoolCount > poolCount) {
      let storedPoolAddress: string | undefined = undefined;
      for (let i = poolCount; newPoolCount > i; i++) {
        const poolAddress = await curveFactoryContract.pool_list(i);
        console.log(poolAddress);

        const coin0: string = await (await ethers.getContractAt('ICurvePool', poolAddress)).coins(0);
        if (coin0.toLocaleLowerCase() === stable.address.toLocaleLowerCase()) {
          await save('CurvePool', {
            abi: ICurvePool.abi,
            address: poolAddress
          });

          const farmInfoPath = path.join(__dirname, '../build/farminfo.json');
          const farmInfo = fs.existsSync(farmInfoPath)
            ? JSON.parse((await fs.promises.readFile(farmInfoPath)).toString())
            : {};

          const chainId = await getChainId();
          if (!(chainId in farmInfo)) {
            farmInfo[chainId] = { curvePoolIdx: i };
          } else {
            farmInfo[chainId].curvePoolIdx = i;
          }
          await fs.promises.writeFile(farmInfoPath, JSON.stringify(farmInfo, null, 2));

          console.log(`CurvePool deployed at ${poolAddress}`);
          storedPoolAddress = poolAddress;

          await assignMainCharacter(deployments, poolAddress, CURVE_POOL, 'curve pool');
          break;
        }
      }

      if (!storedPoolAddress) {
        throw `No stored pool address found in ${curveFactory} between ${poolCount} and ${newPoolCount}`;
      }
    } else {
      throw `Pool did not successfully deploy (yet?)`;
    }
  } else {
    console.log(`CurvePool already deployed at ${existing.address}`);
  }
};

deploy.tags = ['CurvePool', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin'];
export default deploy;
