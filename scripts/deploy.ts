import 'dotenv/config'
import { ethers, upgrades } from 'hardhat'
import Consul from "consul"

async function main() {
  let consul
  const consulToken = process.env.CONSUL_TOKEN || undefined
  let atorContractAddress = process.env.ATOR_TOKEN_CONTRACT_ADDRESS

  if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
    console.log(`Connecting to Consul at ${process.env.CONSUL_IP}:${process.env.CONSUL_PORT}...`)
    consul = new Consul({
      host: process.env.CONSUL_IP,
      port: process.env.CONSUL_PORT,
    });

    atorContractAddress = (await consul.kv.get({
      key: process.env.ATOR_TOKEN_CONSUL_KEY || 'dummy-path',
      token: consulToken
    })).Value
  }

  console.log(`Deploying registrator with ator contract: ${atorContractAddress}`)

  const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY
  const [ owner ] = await ethers.getSigners()

  const deployer = deployerPrivateKey
    ? new ethers.Wallet(
        deployerPrivateKey,
        new ethers.JsonRpcProvider(process.env.JSON_RPC)
      )
    : owner
  
  const operatorAddress = process.env.REGISTRATOR_OPERATOR_ADDRESS || '0x90F79bf6EB2c4f870365E785982E1f101E93b906' // Hardhat #3

  console.log(`Deploying registrator with operator ${operatorAddress}...`)
  console.log(`Deploying registrator with deployer ${deployer.address}...`)
  
  const Contract = await ethers.getContractFactory('Registrator', deployer)

  const defaultBlockLock = 5n * 60n * 24n * 180n // 12s per block, 180 days
  
  const instance = await upgrades.deployProxy(
    Contract,
    [ atorContractAddress, operatorAddress, defaultBlockLock ]
  )
  await instance.waitForDeployment()
  const proxyContractAddress = await instance.getAddress()
  console.log(`Proxy deployed to ${proxyContractAddress}`)

  // const result = await Contract.deploy()
  // await result.deployed()
  // console.log(`Contract deployed to ${result.address}`)

  if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
    const consulKey = process.env.REGISTRATOR_CONSUL_KEY || 'registrator-goerli/test-deploy'

    const updateResult = await consul.kv.set({
      key: consulKey,
      value: proxyContractAddress,
      token: consulToken
    });
    console.log(`Cluster variable ${consulKey} updated: ${updateResult}`)
  } else {
    console.warn('Deployment env var PHASE not defined, skipping update of cluster variable in Consul.')
  }

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
