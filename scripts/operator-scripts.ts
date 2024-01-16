import 'dotenv/config'
import { ethers, upgrades } from 'hardhat'
import Consul from "consul"
import BigNumber from 'bignumber.js'

import { abi } from '../artifacts/contracts/Registrator.sol/Registrator.json'

async function main() {
    const isLocal = (process.env.PHASE === undefined)
    const accountsCount = (isLocal)? 1 : 20;
    
    // this is for debug only, runtime gets data from consul
    let registratorAddress = (isLocal)? 
      process.env.REGISTRATOR_CONTRACT_ADDRESS || '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318' :
      '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318'
      
    let consul
    const consulToken = process.env.CONSUL_TOKEN || undefined

    if (process.env.PHASE !== undefined && process.env.CONSUL_IP !== undefined) {
      console.log(`Connecting to Consul at ${process.env.CONSUL_IP}:${process.env.CONSUL_PORT}...`)
      consul = new Consul({
        host: process.env.CONSUL_IP,
        port: process.env.CONSUL_PORT,
      });

      registratorAddress = (await consul.kv.get({
        key: process.env.REGISTRATOR_CONSUL_KEY || 'dummy-path',
        token: consulToken
      })).Value
    }
      
    const provider = 
      new ethers.JsonRpcProvider(
          (isLocal)? 'http://127.0.0.1:8545/' : 
              process.env.JSON_RPC || 'http://127.0.0.1:8545/'
      )


    const operatorAddress = process.env.REGISTRATOR_OPERATOR_ADDRESS || '0x90F79bf6EB2c4f870365E785982E1f101E93b906' // Hardhat #3
    const operator = new ethers.Wallet(operatorAddress, provider)
    console.log(`Operator ${operator.address}`)

    // const receiverAddress = process.env.REGISTRATOR_RECEIVER_ADDRESS || '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65' // Hardhat #4

    const registratorContract = new ethers.Contract(registratorAddress, abi, operator.provider)
    const registrator = registratorContract.connect(operator)

    try {
      const RATE = 1_000_000;  
      const amount = BigNumber(RATE).toFixed(0)
      const result = await registrator.setRate(1_000_000)
      console.log(`Registrator.setRate(${amount}) tx ${result.hash} waiting for confirmation...`)

      await result.wait()
      console.log(`Operator tx ${result.hash} confirmed!`)
    } catch(error) {
      console.error('Failed running operator script', error)
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
