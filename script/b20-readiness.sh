#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source .env
set +a

CAST_BIN="${CAST_BIN:-$(command -v base-cast || command -v cast)}"
RPC_URL="${RPC_URL:-https://sepolia.base.org}"

B20_FACTORY="0xB20f000000000000000000000000000000000000"
ACTIVATION_REGISTRY="0x8453000000000000000000000000000000000001"

call() {
  "$CAST_BIN" call --rpc-url "$RPC_URL" "$@"
}

bool_call() {
  call "$@" | awk '{ print $1 }'
}

role_hash() {
  "$CAST_BIN" keccak "$1"
}

expect_true() {
  local label="$1"
  local value="$2"
  if [[ "$value" != "true" ]]; then
    echo "FAIL $label=$value"
    exit 1
  fi
  echo "OK $label=true"
}

echo "Beryl Bits B20 readiness"
echo "RPC: $RPC_URL"
echo "B20 asset: $B20_TOKEN_ADDRESS"

B20_ASSET_KEY="$("$CAST_BIN" keccak "base.b20_asset")"
ASSET_ACTIVE="$(bool_call "$ACTIVATION_REGISTRY" "isActivated(bytes32)(bool)" "$B20_ASSET_KEY")"
expect_true "activation.base.b20_asset" "$ASSET_ACTIVE"

IS_B20="$(bool_call "$B20_FACTORY" "isB20(address)(bool)" "$B20_TOKEN_ADDRESS")"
expect_true "factory.isB20" "$IS_B20"

MINT_ROLE="$(role_hash "MINT_ROLE")"
BURN_ROLE="$(role_hash "BURN_ROLE")"

expect_true "curve.MINT_ROLE" "$(bool_call "$B20_TOKEN_ADDRESS" "hasRole(bytes32,address)(bool)" "$MINT_ROLE" "$CURVE_PROXY_ADDRESS")"
expect_true "curve.BURN_ROLE" "$(bool_call "$B20_TOKEN_ADDRESS" "hasRole(bytes32,address)(bool)" "$BURN_ROLE" "$CURVE_PROXY_ADDRESS")"
expect_true "forge.MINT_ROLE" "$(bool_call "$B20_TOKEN_ADDRESS" "hasRole(bytes32,address)(bool)" "$MINT_ROLE" "$FORGE_PROXY_ADDRESS")"
expect_true "forge.BURN_ROLE" "$(bool_call "$B20_TOKEN_ADDRESS" "hasRole(bytes32,address)(bool)" "$BURN_ROLE" "$FORGE_PROXY_ADDRESS")"

echo "B20 readiness checks passed."
