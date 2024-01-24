import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe("Registrator contract", function () {

  const defaultLockBlocks = 10n;

  async function deploy() {
    const Token = await ethers.getContractFactory('Token')
    const Registrator = await ethers.getContractFactory('Registrator')
    const [ admin, tester, operator, receiver ] = await ethers.getSigners()

    const token = await Token.deploy(100_000_000n * BigInt(1e18))
    const tokenAddress = await token.getAddress()

    const registrator = await upgrades.deployProxy(
      Registrator,
      [ tokenAddress, operator.address, defaultLockBlocks ]
    )
    await registrator.waitForDeployment()
    const registratorAddress = await registrator.getAddress()

    return {
      Registrator,
      registrator,
      registratorAddress,
      admin,
      tester,
      operator,
      token,
      tokenAddress,
      receiver
    }
  }

  it('Deploys with a reference to provided token contract address', async () => {
    const { registrator, tokenAddress } = await loadFixture(deploy)
    expect(await registrator.tokenContract()).to.equal(tokenAddress)
  })

  it('Lock tokens for a pre-configured amount of blocks', async() => {
    const { admin, registrator, tester, token, registratorAddress } = 
      await loadFixture(deploy)

    const lockAmount = 100n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, 2n * lockAmount)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount)
    // @ts-ignore
    const result = await registrator.connect(tester).lock(lockAmount)
    
    expect(await token.balanceOf(registratorAddress)).to.equal(lockAmount)
    expect(await token.balanceOf(tester.address)).to.equal(lockAmount)

    const data = await registrator.getLock(tester.address)
    expect(data[0][0]).to.equal(lockAmount)
  })
  
  it('Allows locking tokens for a specific address', async () => {
    const { admin, registrator, tester, token, registratorAddress, receiver } = 
      await loadFixture(deploy)

    const lockAmount = 100n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, 2n * lockAmount)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount)
    // @ts-ignore
    const result = await registrator.connect(tester).lockFor(receiver.address, lockAmount)
    
    expect(await token.balanceOf(registratorAddress)).to.equal(lockAmount)
    expect(await token.balanceOf(tester.address)).to.equal(lockAmount)

    const data = await registrator.getLock(receiver.address)
    expect(data[0][0]).to.equal(lockAmount)
  })

  it('Allows setting only non-zero lock lengths', async () => {
    const { registrator, operator } = await loadFixture(deploy)

    expect(await registrator.lockBlocks()).to.equal(defaultLockBlocks)
    // @ts-ignore
    await expect(registrator.connect(operator).setLockBlocks(0)).to.be.revertedWith(`Lock duration has to be non-zero`)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 2n)
    expect(await registrator.lockBlocks()).to.equal(defaultLockBlocks * 2n)
  })

  it('Block unlocking tokens before unlock height', async () => {
    const { admin, registrator, tester, token, registratorAddress } = 
      await loadFixture(deploy)

    const lockAmount = 100n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, 2n * lockAmount)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount)
    // @ts-ignore
    const result = await registrator.connect(tester).lock(lockAmount)

    const data = await registrator.getLock(tester.address)
    expect(data[0][0]).to.equal(lockAmount)

    // @ts-ignore
    await expect(registrator.connect(tester).unlock(lockAmount)).to.be.revertedWith("No unlockables found")

  })

  it('Allows unlocking tokens starting at unlock height', async () => {
    const { admin, registrator, tester, token, registratorAddress } = 
      await loadFixture(deploy)

    const lockAmount = 100n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, lockAmount)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount)
    // @ts-ignore
    const result = await registrator.connect(tester).lock(lockAmount)
    expect(await token.balanceOf(tester.address)).to.equal(0)

    for (let i = 0; i < defaultLockBlocks; i++) {
      await network.provider.send("evm_mine")
    }
    
    // @ts-ignore
    await registrator.connect(tester).unlock(lockAmount)
    expect(await token.balanceOf(tester.address)).to.equal(lockAmount)
  })

  it('Unlocks exact amount of tokens among multiple locks', async () => {
    const { admin, registrator, tester, token, registratorAddress, operator } = 
      await loadFixture(deploy)

    const lockAmount1 = 1n * BigInt(1e18)
    const lockAmount2 = 10n * BigInt(1e18)
    const lockAmount3 = 100n * BigInt(1e18)
    const lockAmount4 = 1000n * BigInt(1e18)
    const lockAmount5 = 10000n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, lockAmount1 + lockAmount2 + lockAmount3 + lockAmount4 + lockAmount5)
    
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount1)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount1)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 2n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount2)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount2)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 3n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount3)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount3)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 4n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount4)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount4)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 5n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount5)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount5)


    for (let i = 0; i < defaultLockBlocks * 3n; i++) {
      await network.provider.send("evm_mine")
    }
    
    // @ts-ignore
    await registrator.connect(tester).unlock(lockAmount5)

    expect(await token.balanceOf(tester.address)).to.equal(lockAmount1 + lockAmount2 + lockAmount3)
    
    const data = await registrator.getLock(tester.address)
    
    expect(data[0][0]).to.equal(lockAmount4)
  })

  it('Unlocks partial amount of tokens among multiple locks', async () => {
    const { admin, registrator, tester, token, registratorAddress, operator } = 
      await loadFixture(deploy)

    const lockAmount1 = 1n * BigInt(1e18)
    const lockAmount2 = 10n * BigInt(1e18)
    const lockAmount3 = 100n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, lockAmount1 + lockAmount2 + lockAmount3)
    
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount1)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount1)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 2n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount2)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount2)
    // @ts-ignore
    await registrator.connect(operator).setLockBlocks(defaultLockBlocks * 3n)
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount3)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount3)

    for (let i = 0; i < defaultLockBlocks * 2n; i++) {
      await network.provider.send("evm_mine")
    }
    
    // @ts-ignore
    await registrator.connect(tester).unlock(lockAmount1 + (lockAmount2 / 2n))

    expect(await token.balanceOf(tester.address)).to.equal(lockAmount1 + (lockAmount2 / 2n))
    
    const data = await registrator.getLock(tester.address)
    
    expect(data[0][0]).to.equal(lockAmount2 / 2n)
  })

  it('Allows setting penalties per address', async () => {
    const { registrator, operator, tester } = await loadFixture(deploy)

    expect(await registrator.penalties(tester.address)).to.equal(0)
    // @ts-ignore
    await registrator.connect(operator).setPenalty(tester.address, 100)
    
    expect(await registrator.penalties(tester.address)).to.equal(100)
    // @ts-ignore
    await registrator.connect(operator).setPenalty(tester.address, 0)
    
    expect(await registrator.penalties(tester.address)).to.equal(0)
  })

  it('Allows locking tokens after clearing data', async () => {
    const { admin, registrator, tester, token, registratorAddress, operator } = 
      await loadFixture(deploy)

    const preData = await registrator.getLock(tester.address)
    expect(preData[0].length).to.equal(0)

    const lockAmount = 1n * BigInt(1e18)

    // @ts-ignore
    await token.connect(admin).transfer(tester.address, lockAmount)
    
    // @ts-ignore
    await token.connect(tester).approve(registratorAddress, lockAmount)
    // @ts-ignore
    await registrator.connect(tester).lock(lockAmount)
    
    for (let i = 0; i < defaultLockBlocks; i++) {
      await network.provider.send("evm_mine")
    }
    
    // @ts-ignore
    await registrator.connect(tester).unlock(lockAmount)

    expect(await token.balanceOf(tester.address)).to.equal(lockAmount)
    
    const postData = await registrator.getLock(tester.address)
    expect(postData[0].length).to.equal(0)
  })
});
