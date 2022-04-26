const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const pgp = require("pg-promise")();
const kidsAbi = require("./abis/kids.json");
const pupsAbi = require("./abis/pups.json");

const { DATABASE_URL, RPC_URL } = process.env;
const db = pgp(DATABASE_URL);
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const kidsAddress = "0xa5ae87B40076745895BB7387011ca8DE5fde37E0";
const pupsAddress = "0x86e9C5ad3D4b5519DA2D2C19F5c71bAa5Ef40933";
const kidsContract = new ethers.Contract(kidsAddress, kidsAbi, provider);
const pupsContract = new ethers.Contract(pupsAddress, pupsAbi, provider);

const go = async (id, pathName) => {
  if (id === 0) {
    fs.writeFileSync(pathName, "");
    const clearKidsRes = await db.any("DELETE FROM kids RETURNING *");
    const clearPupsRes = await db.any("DELETE FROM pups RETURNING *");
    console.log({ clearPupsRes, clearKidsRes });
  }
  const blockNumber = await provider.getBlockNumber();
  const kidOwner = await kidsContract.ownerOf(id);
  const pupOwner = await pupsContract.ownerOf(id);
  try {
    const dbKidsRes = await db.any(
      "INSERT INTO kids(id, account) VALUES($<id>, $<kidOwner>) RETURNING *",
      {
        id,
        kidOwner,
      }
    );
    console.log({ dbKidsRes });
  } catch (kidsError) {
    console.log({ kidsError });
  }
  try {
    const dbPupsRes = await db.any(
      "INSERT INTO pups(id, account) VALUES($<id>, $<pupOwner>) RETURNING *",
      {
        id,
        pupOwner,
      }
    );
    console.log({ dbPupsRes });
  } catch (kidsError) {
    console.log({ kidsError });
  }
  console.log({ id, blockNumber, kidOwner, pupOwner });
  fs.appendFileSync(
    pathName,
    JSON.stringify({ id, blockNumber, kidOwner, pupOwner })
  );
  if (id < 10_000 - 1) {
    go(id + 1, pathName);
  } else {
    process.exit(0);
  }
};

const transform = async (id) => {
  console.log({ id });
  if (id === 0) {
    const clearKidHoldersRes = await db.any(
      "DELETE FROM kid_holders RETURNING *"
    );
    const clearPupHoldersRes = await db.any(
      "DELETE FROM pup_holders RETURNING *"
    );
    console.log({ clearKidHoldersRes, clearPupHoldersRes });
  }
  try {
    const dbKidsRes = await db.one(
      "SELECT account FROM kids WHERE id = $<id>",
      { id }
    );
    const kidsAccount = dbKidsRes.account;
    const existingKidsHoldingsRes = await db.any(
      "SELECT kid_count FROM kid_holders WHERE account = $<kidsAccount>",
      { kidsAccount }
    );
    if (existingKidsHoldingsRes.length) {
      const prevKidCount = existingKidsHoldingsRes[0].kid_count;
      const newKidCount = prevKidCount + 1;
      const incrementKidsHoldingsRes = await db.any(
        "UPDATE kid_holders SET kid_count = $<newKidCount> WHERE account = $<kidsAccount> RETURNING *",
        { newKidCount, kidsAccount }
      );
      console.log({ prevKidCount, newKidCount, incrementKidsHoldingsRes });
    } else {
      const createKidHoldingsRes = await db.any(
        "INSERT INTO kid_holders(account, kid_count) VALUES($<kidsAccount>, 1) RETURNING *",
        { kidsAccount }
      );
      console.log({ createKidHoldingsRes });
    }
    const dbPupsRes = await db.one(
      "SELECT account FROM pups WHERE id = $<id>",
      { id }
    );
    const pupsAccount = dbPupsRes.account;
    const existingPupsHoldingsRes = await db.any(
      "SELECT pup_count FROM pup_holders WHERE account = $<pupsAccount>",
      { pupsAccount }
    );
    if (existingPupsHoldingsRes.length) {
      const prevPupCount = existingPupsHoldingsRes[0].pup_count;
      const newPupCount = prevPupCount + 1;
      const incrementPupHoldingsRes = await db.any(
        "UPDATE pup_holders SET pup_count = $<newPupCount> WHERE account = $<pupsAccount> RETURNING *",
        { newPupCount, pupsAccount }
      );
      console.log({ prevPupCount, newPupCount, incrementPupHoldingsRes });
    } else {
      const createPupsHoldingsRes = await db.any(
        "INSERT INTO pup_holders(account, pup_count) VALUES($<pupsAccount>, 1) RETURNING *",
        { pupsAccount }
      );
      console.log({ createPupsHoldingsRes });
    }
  } catch (error) {
    console.log({ error });
  }
  if (id < 10_000 - 1) {
    transform(id + 1, pathName);
  } else {
    process.exit(0);
  }
};

// if any transfers were executed while running the snapshot script,
// reset them to reflect the state at the initial block of the snapshot
const adjust = async ({ fromBlock, toBlock }) => {
  const adjustments = [];
  const kidTransferFilter = kidsContract.filters.Transfer();
  const kidTransferEvents = await kidsContract.queryFilter(
    kidTransferFilter,
    fromBlock,
    toBlock
  );
  for (const event of kidTransferEvents) {
    const { args } = event;
    const { from, to, tokenId } = args;
    const id = tokenId.toNumber();
    adjustments.push({ from, to, id, collection: "kids" });
  }
  const pupTransferFilter = pupsContract.filters.Transfer();
  const pupTransferEvents = await pupsContract.queryFilter(
    pupTransferFilter,
    fromBlock,
    toBlock
  );
  for (const event of pupTransferEvents) {
    const { args } = event;
    const { from, to, tokenId } = args;
    const id = tokenId.toNumber();
    adjustments.push({ from, to, id, collection: "pups" });
  }
  for (const adjustment of adjustments) {
    const { id, from, to, collection } = adjustment;
    if (collection === "kids") {
      const adjustKidsRes = await db.any(
        "UPDATE kids SET account = $<from> WHERE account = $<to> AND id = $<id> RETURNING *",
        { from, id, to }
      );
      console.log({ adjustKidsRes });
    } else if (collection === "pups") {
      const adjustPupsRes = await db.any(
        "UPDATE pups SET account = $<from> WHERE account = $<to> AND id = $<id> RETURNING *",
        { from, id, to }
      );
      console.log({ adjustPupsRes });
    }
  }
};

const pathName = path.join(__dirname, `logs/${Date.now()}.txt`);

// uncomment to take snapshot
// go(0, pathName);

// uncomment to adjust for sales made while running snapshot script
// fromBlock and toBlock need to be set manually based on logs from
// snapshot
// adjust({ fromBlock: TK, toBlock: TK });

// uncomment to run transformations
// transform(0);
