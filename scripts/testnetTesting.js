const { ethers } = require("ethers");
const kidsAbi = require("./abis/kids.json");
const pupsAbi = require("./abis/pups.json");
const stakingAbi = require("./abis/staking.json");
const gumAbi = require("./abis/gum.json");

const { GUM_PRIV_KEY, GUM_ADDY, GUM_RANDO_PRIV_KEY, GUM_RANDO_ADDY, RPC_URL } =
  process.env;

const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(GUM_PRIV_KEY, provider);

const kidsAddress = "0x13a5f9a34a5597ac821f551447446d363a945569";
const pupsAddress = "0xf0a2f967a55492b3db4ffbf1ee7de6bd5cf34009";
const stakingAddress = "0x5cdfd0b428b47aeb9ba307355da1e7971c62fa06";
const gumAddress = "0xe5f1433b6eCc6bE74E413b54f4c1eA2671b1cA0F";
const randomAddress = "0x03801efb0efe2a25ede5dd3a003ae880c0292e4d";

const kidsContract = new ethers.Contract(kidsAddress, kidsAbi, signer);
const pupsContract = new ethers.Contract(pupsAddress, pupsAbi, signer);
const stakingContract = new ethers.Contract(stakingAddress, stakingAbi, signer);
const gumContract = new ethers.Contract(gumAddress, gumAbi, signer);

const go = async () => {
  // const tx = await gumContract.updateStaking(stakingAddress);
  // const tx = await kidsContract.mint(1, {
  //   value: ethers.utils.parseEther("0.06"),
  // });
  // const tx = await pupsContract.purchasePuppies(1, {
  //   value: ethers.utils.parseEther("0.06"),
  // });
  // const owner = await kidsContract.ownerOf(4);
  // console.log({ owner });
  // const tx = await stakingContract.start();
  // const tx = await kidsContract.approve(stakingAddress, 7);
  // const tx = await stakingContract.deposit([6], [0]);
  // const tx = await stakingContract.claimRewards();
  // const tx = await stakingContract.lock([4], [3], [0]);
  // const tx = await pupsContract.approve(stakingAddress, 4);
  // const tx = await kidsContract.transferFrom(GUM_ADDY, GUM_RANDO_ADDY, 4);
  // const res = await tx.wait();
  // console.log({ tx, res });
};

go();
