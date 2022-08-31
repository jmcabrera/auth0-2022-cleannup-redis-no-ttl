import * as Redis from "ioredis";
import * as dotenv from "dotenv"; // see https://github.com/motdotla/dotenv#how-do-i-use-dotenv-with-import
dotenv.config();

const port = parseInt(process.env["REDIS_PORT"] || "6379");
const host = process.env["REDIS_HOST"] || "localhost";
const password = process.env["REDIS_PWD"] || "";

const cluster = new Redis.Cluster([{ port, host }], {
  dnsLookup: (address, callback) => {
    callback(null, address);
  },
  redisOptions: { password, tls: {} },
});

const BATCH = 1000000; // There will be BATCH elements inserted
const SIZE = 200; // The size of 1 entry, in Bytes
const KEY_PREFIX = "jmc-test-";
const KEY_PREFIX_UNIQUE = KEY_PREFIX + Date.now() + "-";
const PAYLOAD = Array.from(Array(SIZE)) // The actual value for every key
  .map((_) => "" + Math.floor(Math.random() * 10))
  .reduce((acc, cur) => acc + cur);

async function insertGarbage() {
  var ok = 0;
  var err = 0;
  for (var i = 0; i < BATCH; i++) {
    const key = KEY_PREFIX_UNIQUE + i;
    var res = await cluster.set(key, PAYLOAD);
    if ("OK" === res) {
      ok++;
    } else {
      err++;
    }
  }
  console.log("done: ", ok, " errors: ", err);
}

async function main() {
  // needed to gracefully connect the cluster...
  await cluster.info();
  console.log("insert");
  await insertGarbage();
  return cluster.disconnect();
}

main().then(() => console.log("finished"));
