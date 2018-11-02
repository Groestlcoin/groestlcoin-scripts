#!/bin/bash
# This script will periodically query a groestlcoin fullnode for the curreny number of block synched,
# and calculate the block synchronization rate and predicted completion time.
# Please configure location of groestlcoin.conf and get_local_blocks function.

sleep_m=10 # polling period in minutes
n=36.0 # moving average number for block sync rate in polling periods
net_n=144.0 # moving average number for network block mining rate in polling periods
conf=/media/groestlcoin/groestlcoin.conf # location of groestlcoin.conf

function get_local_blocks {
	groestlcoin-cli --conf=$conf getblockcount
}

function get_net_blocks {
	wget -q -O- http://chainz.cryptoid.info/grs/api.dws?q=getblockcount
}

sleep_s=$(echo $sleep_m '*' 60 | bc -l)
alpha=$(echo 2 / \( $n + 1 \) | bc -l )
net_alpha=$(echo 2 / \( $net_n + 1 \) | bc -l )
net_ma=0
local_ma=0
netblock=0
localblock=0
while true; do
	echo "$(date) - Getting counts..."
	time_before=$(date '+%s')
	netblock_old=$netblock
	netblock=$(get_net_blocks)
	if [ "$netblock " == " " ]; then
		netblock=$netblock_old
	fi
	localblock_old=$localblock
	localblock=$(get_local_blocks)
	echo Currently synched $localblock out of $netblock blocks

	if [ "$localblock_old" != "0" ]; then
		net_diff=$(echo $netblock - $netblock_old | bc -l)
		if [ "$net_ma" != "0" ]; then
			net_ma=$(echo \( $net_alpha '*' $net_diff \) + \( $net_ma '*' \( 1 - $net_alpha \) \) | bc -l)
		else
			net_ma=$net_diff
		fi

		local_diff=$(echo $localblock - $localblock_old | bc -l)
		if [ "$local_ma" != "0" ]; then
			local_ma=$(echo \( $alpha '*' $local_diff \) + \( $local_ma  '*' \( 1 - $alpha \) \) | bc -l)
		else
			local_ma=$local_diff
		fi

		time=$(echo \( $netblock - $localblock \) / \( $local_ma - $net_ma \) | bc -l )
		minutes=$(printf "%.0f" "$(echo $time \* $sleep_m | bc -l)")
		net_ma_hr=$(echo \( $net_ma / $sleep_m \) '*' 60 | bc -l)
		local_ma_hr=$(echo \( $local_ma / $sleep_m \) '*' 60 | bc -l)
		printf 'Synching at %.2f blk/hr. new blocks being generated at %.2f blk/hr.\n' $local_ma_hr  $net_ma_hr
		printf 'Estimated time remaining: %d days, %d hours, %d minutes\n' $(($minutes/1440)) $(($minutes%1440/60)) $(($minutes%60))
	fi

	time_after=$(date '+%s')
	time_diff=$(echo $time_after - $time_before | bc -l)
	sleep_s_adj=$(echo $sleep_s - $time_diff | bc -l)
	if (( $sleep_s_adj > 0 )); then
		echo "Took $time_diff seconds. Sleeping for $sleep_s_adj seconds."
		sleep ${sleep_s_adj}s
	else
		echo "Took $time_diff seconds."
		echo "Warning: Query took longer than polling interval (${sleep_s_adj}s), calculations may be inaccurate. Not sleeping."
	fi
done
