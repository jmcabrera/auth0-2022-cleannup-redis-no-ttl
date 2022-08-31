# Cleaning a Redis from entries without TTL

A companion repo to https://oktawiki.atlassian.net/wiki/spaces/PIPE/pages/2698906125/Cleaning+Redis+Elasticache


## With Bash
Work in progress, do not use. (Will probably go stale)
## With NodeJS

### usage
There are 2 scripts here:
- `cleanup.ts` that will clean a redis cluster from its entries without a TTL
- `insert.ts` that is to be used **on non productive envs _ONLY_** to load 1 million entries without a TTL for testing purposes.

Needs: Node >= 16

To run either one, the process is similar:
- `npm ci`
- create a `.env` file (see below)
- run either `npm run insert` to insert or `npm run cleanup` to cleanup

Example `.env` file:

```shell
REDIS_PWD=yourlongandsecretpassword
REDIS_HOST=clustercfg.tus2-entities-uw2.deadbee.usw2.cache.amazonaws.com
REDIS_PORT=6379
```

### details
Insertion is done sequentially.

Deletion is done in parallel on each master node.
We use `SCAN` to crawl each node, since it is way less perturbing for the cluster than using the (simpler) `KEYS`