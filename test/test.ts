import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe("Registrator contract", function () {

  async function deploy() {
    const Token = await ethers.getContractFactory('Token')
    const Registrator = await ethers.getContractFactory('Registrator')
    const [ admin, tester, operator, receiver ] = await ethers.getSigners()

    const token = await Token.deploy(100_000_000n * BigInt(1e18))
    const tokenAddress = await token.getAddress()

    const registrator = await upgrades.deployProxy(
      Registrator,
      [ tokenAddress, operator.address, receiver.address ]
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
      receiver,
      token,
      tokenAddress
    }
  }

  it('Deploys with a reference to provided token contract address', async () => {
    const { registrator, tokenAddress } = await loadFixture(deploy)
    expect(await registrator.tokenContract()).to.equal(tokenAddress)
  })

  it('Lock tokens for a pre-configured amount of blocks')
  it('Allows setting non-zero lock lengths')
  it('Block unlocking tokens before unlock height')
  it('Allows unlocking tokens starting at unlock height')

});
