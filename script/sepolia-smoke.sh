#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source .env
set +a

RPC_URL="${RPC_URL:-https://sepolia.base.org}"
PRIVATE_KEY="${SEPOLIA_TEST_PRIVATE_KEY:-$DEPLOYER_PRIVATE_KEY}"
ACTOR="$DEPLOYER_ADDRESS"
ONE_UNIT="1000000000000000000"

send() {
  cast send --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --confirmations 1 --timeout 120 "$@"
  sleep 2
}

call() {
  cast call --rpc-url "$RPC_URL" "$@"
}

uint_call() {
  call "$@" | awk '{ print $1 }'
}

field() {
  awk -v key="$1" '$1 == key { print $2 }'
}

tx_hash() {
  field "transactionHash"
}

echo "Beryl Bits Sepolia smoke"
echo "Actor: $ACTOR"
echo "B20: $B20_TOKEN_ADDRESS"
echo "Curve: $CURVE_PROXY_ADDRESS"
echo "Forge: $FORGE_PROXY_ADDRESS"
echo "NFT: $NFT_PROXY_ADDRESS"

START_OUTSTANDING="$(uint_call "$CURVE_PROXY_ADDRESS" 'marketOutstandingUnits()(uint256)')"
START_B20_SUPPLY="$(uint_call "$B20_TOKEN_ADDRESS" 'totalSupply()(uint256)')"
START_LIVE_SUPPLY="$(uint_call "$NFT_PROXY_ADDRESS" 'liveSupply()(uint256)')"
START_TOTAL_MINTED="$(uint_call "$NFT_PROXY_ADDRESS" 'totalMinted()(uint256)')"

echo "start.outstanding=$START_OUTSTANDING"
echo "start.b20TotalSupply=$START_B20_SUPPLY"
echo "start.nftLiveSupply=$START_LIVE_SUPPLY"
echo "start.nftTotalMinted=$START_TOTAL_MINTED"

BUY_ONE_COST="$(uint_call "$CURVE_PROXY_ADDRESS" 'quoteBuy(uint256)(uint256)' 1)"
BUY_ONE_TX="$(send "$CURVE_PROXY_ADDRESS" 'buy(uint256,uint256)' 1 "$BUY_ONE_COST" --value "$BUY_ONE_COST" | tx_hash)"
APPROVE_FORGE_ONE_TX="$(send "$B20_TOKEN_ADDRESS" 'approve(address,uint256)' "$FORGE_PROXY_ADDRESS" "$ONE_UNIT" | tx_hash)"
FIRST_TOKEN_ID="$((START_TOTAL_MINTED + 1))"
FORGE_ONE_TX="$(send "$FORGE_PROXY_ADDRESS" 'forge(uint256)' 1 | tx_hash)"
MIN_PAYOUT_ONE="$(uint_call "$CURVE_PROXY_ADDRESS" 'quoteSell(uint256)(uint256)' 1)"
REDEEM_AND_SELL_TX="$(send "$FORGE_PROXY_ADDRESS" 'redeemAndSell(uint256[],uint256)' "[$FIRST_TOKEN_ID]" "$MIN_PAYOUT_ONE" | tx_hash)"

BUY_TWO_COST="$(uint_call "$CURVE_PROXY_ADDRESS" 'quoteBuy(uint256)(uint256)' 2)"
BUY_TWO_TX="$(send "$CURVE_PROXY_ADDRESS" 'buy(uint256,uint256)' 2 "$BUY_TWO_COST" --value "$BUY_TWO_COST" | tx_hash)"
APPROVE_FORGE_TWO_TX="$(send "$B20_TOKEN_ADDRESS" 'approve(address,uint256)' "$FORGE_PROXY_ADDRESS" "$((2 * ONE_UNIT))" | tx_hash)"
SECOND_TOTAL_MINTED="$(uint_call "$NFT_PROXY_ADDRESS" 'totalMinted()(uint256)')"
SECOND_FIRST_TOKEN_ID="$((SECOND_TOTAL_MINTED + 1))"
SECOND_SECOND_TOKEN_ID="$((SECOND_TOTAL_MINTED + 2))"
FORGE_TWO_TX="$(send "$FORGE_PROXY_ADDRESS" 'forge(uint256)' 2 | tx_hash)"
REDEEM_ONE_TX="$(send "$FORGE_PROXY_ADDRESS" 'redeem(uint256[])' "[$SECOND_FIRST_TOKEN_ID]" | tx_hash)"
APPROVE_CURVE_TX="$(send "$B20_TOKEN_ADDRESS" 'approve(address,uint256)' "$CURVE_PROXY_ADDRESS" "$ONE_UNIT" | tx_hash)"
MIN_PAYOUT_TWO="$(uint_call "$CURVE_PROXY_ADDRESS" 'quoteSell(uint256)(uint256)' 1)"
SELL_ONE_TX="$(send "$CURVE_PROXY_ADDRESS" 'sell(uint256,uint256)' 1 "$MIN_PAYOUT_TWO" | tx_hash)"

END_OUTSTANDING="$(uint_call "$CURVE_PROXY_ADDRESS" 'marketOutstandingUnits()(uint256)')"
END_B20_SUPPLY="$(uint_call "$B20_TOKEN_ADDRESS" 'totalSupply()(uint256)')"
END_ACTOR_B20="$(uint_call "$B20_TOKEN_ADDRESS" 'balanceOf(address)(uint256)' "$ACTOR")"
END_ACTOR_NFT="$(uint_call "$NFT_PROXY_ADDRESS" 'balanceOf(address)(uint256)' "$ACTOR")"
END_LIVE_SUPPLY="$(uint_call "$NFT_PROXY_ADDRESS" 'liveSupply()(uint256)')"
END_TOTAL_MINTED="$(uint_call "$NFT_PROXY_ADDRESS" 'totalMinted()(uint256)')"
END_CURVE_ETH="$(cast balance --rpc-url "$RPC_URL" "$CURVE_PROXY_ADDRESS")"

cat <<EOF
flow1.buy=$BUY_ONE_TX
flow1.approveForge=$APPROVE_FORGE_ONE_TX
flow1.forge=$FORGE_ONE_TX
flow1.redeemAndSell=$REDEEM_AND_SELL_TX
flow1.tokenId=$FIRST_TOKEN_ID
flow1.buyCost=$BUY_ONE_COST
flow1.minPayout=$MIN_PAYOUT_ONE
flow2.buy=$BUY_TWO_TX
flow2.approveForge=$APPROVE_FORGE_TWO_TX
flow2.forge=$FORGE_TWO_TX
flow2.redeem=$REDEEM_ONE_TX
flow2.approveCurve=$APPROVE_CURVE_TX
flow2.sell=$SELL_ONE_TX
flow2.tokenIds=$SECOND_FIRST_TOKEN_ID,$SECOND_SECOND_TOKEN_ID
flow2.buyCost=$BUY_TWO_COST
flow2.minPayout=$MIN_PAYOUT_TWO
end.outstanding=$END_OUTSTANDING
end.b20TotalSupply=$END_B20_SUPPLY
end.actorB20Balance=$END_ACTOR_B20
end.actorNftBalance=$END_ACTOR_NFT
end.nftLiveSupply=$END_LIVE_SUPPLY
end.nftTotalMinted=$END_TOTAL_MINTED
end.curveEthBalance=$END_CURVE_ETH
EOF
