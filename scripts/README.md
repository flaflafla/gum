# comicScript

use this file to take a snapshot of Bubblegum Kids and Bubblegum Pups holders

tl;dr

`DATABASE_URL=<database-url> RPC_URL=<rpc-url> node scripts/comicScript.js`

## 0

first, set up a postgres database:

```
create database gum_comic;

create table kids(
    id integer unique,
    account varchar
);

create table pups(
    id integer unique,
    account varchar
);

create table kid_holders(
    account varchar unique,
    kid_count integer
);

create table pup_holders(
    account varchar unique,
    pup_count integer
);
```

you'll pass the database url (eg, `postgres://coolperson@localhost:5432/gum_comic`) to the script as `DATABASE_URL`

you'll also need to pass an rpc url (eg, `https://mainnet.infura.io/v3/l0tsOfNumB3rS`) as `RPC_URL`

## 1

first, take the raw snapshot by uncommenting the `go` function ~line 181: `go(0, pathName);`

this will 🚨 CLEAR 🚨 the `kids` and `pups` tables, then repopulate them with the id of each individual token (0-9999) in both collections and the ethereum account that owns the token

## 2

it takes a couple hundred blocks to run the snapshot, so it's necessary to account for any transfers that might have happened in that interval

re-comment `go(0, pathName);` and uncomment ~line 186: `adjust({ fromBlock: TK, toBlock: TK });`

check the `logs` folder to see at what blocks the (most recent) snapshot began and ended. then replace `fromBlock` and `toBlock` with the corresponding `blockNumber`s in the `adjust` invocation

```
// logs/1649641552205.txt -- the log file names are unix timestamps
{"id":0,"blockNumber":14561502,"kidOwner":"0x624B4fA789872783C1f88AFA3296870dE68EF883","pupOwner":"0x3A71C160022e290065a4252ec826F25a86885a55"}
...
{"id":9999,"blockNumber":14561732,"kidOwner":"0x55B27DBDf5ed21df699A1e152e2449CB6a0d19d8","pupOwner":"0xdC1F69BBDd4A36C2830A5aD1B5D557C4d8A87247"}

// comicScript.js
...
adjust({ fromBlock: 14561502, toBlock: 14561732 });
```

and run the script file again. this will update the `kids` and `pups` tables, making it as though the snapshot had been started and completed instantaneously at the `fromBlock`

## 3

the final step is to transform the data to a more easily queried form

re-comment the `adjust` call and uncomment ~line 189: `transform(0);`

this function will 🚨 CLEAR 🚨 and repopulate the `kid_holders` and `pup_holders` tables based on the data in `kids` and `pups`. the transformation maps an ethereum address to the number of items in the relevant collection that the address owns

now we can find out how many BGK or BGP `0x3236DdfC6a12222BEF7f29FE192b2802C07c1cfe` has by running:

`select * from kid_holders where account = '0x3236DdfC6a12222BEF7f29FE192b2802C07c1cfe';`

and/or

`select * from pup_holders where account = '0x3236DdfC6a12222BEF7f29FE192b2802C07c1cfe';`

## 4

query to get consolidated holdings: 

`select kid_holders.account, kid_count, pup_count from kid_holders join pup_holders on kid_holders.account = pup_holders.account order by kid_count desc;`
