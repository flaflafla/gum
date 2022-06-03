const { ethers } = require("ethers");
const kidsAbi = require("./abis/kids.json");
const pupsAbi = require("./abis/pups.json");
const stakingAbi = require("./abis/staking.json");
const gumAbi = require("./abis/gum.json");

const { GUM_PRIV_KEY, RPC_URL } = process.env;

const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(GUM_PRIV_KEY, provider);

const kidsAddress = "0x13a5f9a34a5597ac821f551447446d363a945569";
const pupsAddress = "0xf0a2f967a55492b3db4ffbf1ee7de6bd5cf34009";
const stakingAddress = "0x6ec471fc2d55db45de540201170cd2d7d3a95ed3";
const gumAddress = "0xe5f1433b6eCc6bE74E413b54f4c1eA2671b1cA0F";

const kidsContract = new ethers.Contract(kidsAddress, kidsAbi, signer);
const pupsContract = new ethers.Contract(pupsAddress, pupsAbi, signer);
const stakingContract = new ethers.Contract(stakingAddress, stakingAbi, signer);
const gumContract = new ethers.Contract(gumAddress, gumAbi, signer);

const go = async () => {
  //   const tx = await kidsContract.mint(1, {
  //     value: ethers.utils.parseEther("0.06"),
  //   });
  //   const tx = await pupsContract.purchasePuppies(1, {
  //     value: ethers.utils.parseEther("0.06"),
  //   });
  //   const tx = await kidsContract.approve(stakingAddress, 0);
  //   const owner = await pupsContract.ownerOf(0);
  //   console.log({ owner });
  //   const tx = await stakingContract.depositAndLock([1], [2], [1]);
  // const tx = await gumContract.updateStaking(stakingAddress);
  // const res = await tx.wait();
  // console.log({ tx, res });
  // const lol = await stakingContract.locksOf(signer.address);
  // console.log(lol);
};

go();
