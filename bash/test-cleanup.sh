#!/bin/bash
#REDIS_CLI="./redis-cli --tls -c -h clustercfg.tus1-entities-uw2.gmpqt9.usw2.cache.amazonaws.com -p 6379 -a uI79mnV8IpYSxSjdAnsrkYnPqtVzOgEO"
export REDISCLI_AUTH=wzywaoJfFwTcqf6LzysepzXxrc3vGj5p
REDIS_CLI="./redis-cli --tls -c -p 6379 -h"
REDIS_CLUSTER="$REDIS_CLI clustercfg.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com"

## Prefix for all inserted keys
PREFIX="jmc-test"

## Number of keys to insert
BATCH=100

## The payload for each key
PAYLOAD="$(head -c 150 /dev/urandom | base64 -w 0)"

## The really interresting function here: Scans and cleans entries with
##   - prefix == $PREFIX-
##	 - no TTL (i.e. a reported TTL of -1)
function _cleanOne() {
	master=$1
	redis_here=$REDIS_CLI "$master"
	cursor=0
	cleaned=0
	skipped=0
	echo $master
	return
	while :; do
		echo "$master at cursor $cursor"
		readarray -t range < <($redis_here SCAN $cursor MATCH "$PREFIX-*" COUNT 1000)
		cursor="${range[0]}"
		if [ "0" == "$cursor" ]; then
			echo "$master done"
			break
		else
			for key in "${range[@]:1}"; do
				[ "" == "$key" ] && continue
				ttl=$($redis_here TTL "$key")
				if [ "$ttl" -eq "-1" ]; then
					echo "$master killing ---: $key (ttl: $ttl)"
					$redis_here DEL $key
					cleaned=$((cleaned+1))
				else
					echo "$master survive    : $key (ttl: $ttl)"
					skipped=$((skipped+1))
				fi
			done
		fi
	done
	echo "$master done: cleaned $cleaned entries, skipped $skipped entries"
}
export -f _cleanOne

function _clean() {
	## Example output for redis-cli CLUSTER NODES:
	## a25bbf48d6018c54a42dcab63c1204a64b2b320c tus2-entities-uw2-0002-002.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave 48cd5ecea1a6991aedbe34052b9855367962298c 0 1661238803000 1 connected
	## 48cd5ecea1a6991aedbe34052b9855367962298c tus2-entities-uw2-0002-001.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 myself,master - 0 1661238801000 1 connected 5462-10922
	## b555443ff5bc161badb5e08d176d265496e3b155 tus2-entities-uw2-0001-001.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 master - 0 1661238801000 3 connected 0-5461
	## c2ef6a392f83281d510fe003fb583093f958e0f6 tus2-entities-uw2-0003-001.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 master - 0 1661238802254 0 connected 10923-16383
	## 102d102c163b01bcf1a94475a50dc823373ee06c tus2-entities-uw2-0001-003.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave b555443ff5bc161badb5e08d176d265496e3b155 0 1661238797230 3 connected
	## 9d124d2e8f700673f5588b974414193bc0adc29c tus2-entities-uw2-0003-002.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave c2ef6a392f83281d510fe003fb583093f958e0f6 0 1661238800245 0 connected
	## 8dc00c9d261ae7fac0a6f6cefdcdbe16542cdcb4 tus2-entities-uw2-0003-003.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave c2ef6a392f83281d510fe003fb583093f958e0f6 0 1661238802000 0 connected
	## 3632d235e0f67bb1747426e3cba74a4f60b95e76 tus2-entities-uw2-0002-003.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave 48cd5ecea1a6991aedbe34052b9855367962298c 0 1661238803255 1 connected
	## 5ae4ce3ce0d0aa803af2401cb57d23e4f9c66b42 tus2-entities-uw2-0001-002.tus2-entities-uw2.wtchhy.usw2.cache.amazonaws.com:6379@1122 slave b555443ff5bc161badb5e08d176d265496e3b155 0 1661238804255 3 connected
	$REDIS_CLUSTER CLUSTER NODES |grep master |grep -o 'tus2-entities.*amazonaws\.com' | parallel -P 10 _cleanOne "{}"
}

function _fill() {
	## Fill the cluster
	(seq 1 $BATCH | parallel -P 10 -I{} $REDIS_CLUSTER SET "$PREFIX-{}" "$PAYLOAD") > filled.txt
	echo "Filled $(grep OK filled.txt | wc -l), got $(grep -v OK filled.txt | wc -l) errors"
}

_fill

_clean