// NOT A WORKING TEST

const { expect } = require("chai");

describe('ShroomelayToken', () => {
  async function deployTokenFixture() {
    const Shroomelay = await ethers.getContractFactory("Shroomelay");
    const [owner, addr1, addr2] = await ethers.getSigners();

    const hardhatToken = await Shroomelay.deploy();

    await hardhatToken.deployed();

    return { Shroomelay, hardhatToken, owner, addr1, addr2 };
  }

  it("Should ", async function() {
    
  });
});
