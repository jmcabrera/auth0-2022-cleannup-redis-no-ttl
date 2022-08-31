import * as Redis from "ioredis";
import * as dotenv from 'dotenv' // see https://github.com/motdotla/dotenv#how-do-i-use-dotenv-with-import
dotenv.config()

const port = parseInt(process.env["REDIS_PORT"] || "6379");
const host = process.env["REDIS_HOST"] || "localhost";
const password = process.env["REDIS_PWD"] || "";

const cluster = new Redis.Cluster([{ port, host }], {
  dnsLookup: (address, callback) => {
    callback(null, address);
  },
  redisOptions: { password, tls: {} },
});

async function cleanGarbage() {
  async function clean(
    r: Redis.Redis | Redis.Cluster,
    name: string,
    cursor = "",
    items: string[] = [],
    done = 0,
    errors = 0
  ): Promise<void> {
    try {
      if ("0" == cursor) {
        console.log(name, "ended, ok: ", done, " errors: ", errors);
        return;
      }
      var doneNow = 0;
      var errNow = 0;
      cursor = !cursor ? "0" : cursor;
      for (var i of items) {
        const ttl = await cluster.ttl(i);
        if (ttl < 0) {
          const res = await r.del(i);
          if (res == 1) {
            doneNow++;
          } else {
            errNow++;
          }
        }
      }
      [cursor, items] = await r.scan(cursor, "COUNT", 1000);
      return clean(r, name, cursor, items, done + doneNow, errors + errNow);
    } catch (error) {
      console.log(name, error);
      console.log(name, "so far, did ", done, " had ", errors, " errors");
    }
  }
  const nodes = cluster.nodes("master");
  var i = 0;
  await Promise.all(nodes.map((n) => clean(n, "node-" + i++)));
}

async function main() {
  await cluster.info();
  console.log("clean");
  await cleanGarbage();
  return cluster.disconnect();
}

main().then(() => console.log("finished"));
