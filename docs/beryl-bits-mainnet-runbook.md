# Beryl Bits — Mainnet Launch Runbook

Everything needed for mainnet, prepared in advance. On launch day the flow is: **pre-flight → deploy → flip frontend env**. The actual mainnet deploy (broadcast) is the only step intentionally left for the operator.

Base Mainnet chain id: **`8453`**.

---

## 0. Pre-flight (do not skip)

### 0.1 B20 activation check

B20 must be activated on Base mainnet before the factory will create an asset (mainnet activation: **2026-06-26 18:00 UTC**, Activation Registry may need ~1h).

```bash
# Activation Registry precompile: 0x8453000000000000000000000000000000000001
# keccak("base.b20_asset"):
#   0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c

cast call --rpc-url "$BASE_MAINNET_RPC_URL" \
  0x8453000000000000000000000000000000000001 \
  'isActivated(bytes32)(bool)' \
  0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c
# must return: true
```

### 0.2 base-forge toolchain

Standard Foundry **cannot** simulate B20 precompile calls. Install Base's fork and use it for the B20 creation step (with `--skip-simulation`):

```bash
base-foundryup            # installs base-forge / base-cast (does not overwrite std foundry)
base-forge --version
```

Curve/forge/NFT (plain EVM) steps can use either standard `forge` or `base-forge`. Only `CreateBerylBitsB20Token` strictly needs `base-forge`.

### 0.3 Funding & balances

```bash
cast balance --rpc-url "$BASE_MAINNET_RPC_URL" "$DEPLOYER_ADDRESS"   # enough for deploy + smoke
```

### 0.4 Metadata host live

`https://berylbits.xyz/contract.json` must resolve (B20 `contractURI`). Confirm before deploy:

```bash
curl -sSf https://berylbits.xyz/contract.json >/dev/null && echo OK
```

---

## 1. Mainnet `.env` (contracts)

Copy into a gitignored `.env` (never commit). All addresses are the **mainnet** deployer-controlled wallet per the current governance decision.

```bash
# --- RPC / keys ---
BASE_MAINNET_RPC_URL="https://mainnet.base.org"      # or a private RPC
DEPLOYER_ADDRESS="0x..."                              # mainnet deployer
DEPLOYER_PRIVATE_KEY="0x..."                          # NEVER commit

# --- Governance (deployer wallet by current decision) ---
ADMIN_ADDRESS="0x..."
TREASURY_ADDRESS="0x..."
TEAM_ADDRESS="0x..."
MULTISIG_ADDRESS="0x..."   # currently = deployer
TIMELOCK_ADDRESS="0x..."   # currently = deployer

# --- B20 creation ---
B20_SALT="0x..."                                      # fresh mainnet salt
B20_CONTRACT_URI="https://berylbits.xyz/contract.json"
BERYL_BITS_WEBSITE="https://berylbits.xyz"
BERYL_BITS_DOCS_URI="https://berylbits.xyz/docs"

# --- Team sell lock ---
TEAM_SELL_UNLOCK_UNITS=1000

# --- Filled in AFTER each deploy step ---
B20_TOKEN_ADDRESS="0x..."     # from step 2
NFT_PROXY_ADDRESS="0x..."     # from step 3
FORGE_PROXY_ADDRESS="0x..."   # from step 3
CURVE_PROXY_ADDRESS="0x..."   # from step 3
```

---

## 2. Create the B20 asset (base-forge)

```bash
base-forge script script/CreateBerylBitsB20Token.s.sol:CreateBerylBitsB20Token \
  --rpc-url "$BASE_MAINNET_RPC_URL" --broadcast --skip-simulation \
  --private-key "$DEPLOYER_PRIVATE_KEY"
```

Record the deployed token address into `B20_TOKEN_ADDRESS`. Verify:

```bash
cast call --rpc-url "$BASE_MAINNET_RPC_URL" 0xB20f000000000000000000000000000000000000 \
  'isB20(address)(bool)' "$B20_TOKEN_ADDRESS"   # true
```

---

## 3. Deploy UUPS system (curve / forge / NFT)

```bash
forge script script/DeployBerylBitsUpgradeableSystem.s.sol:DeployBerylBitsUpgradeableSystem \
  --rpc-url "$BASE_MAINNET_RPC_URL" --broadcast \
  --private-key "$DEPLOYER_PRIVATE_KEY"
```

Record `NFT_PROXY_ADDRESS`, `FORGE_PROXY_ADDRESS`, `CURVE_PROXY_ADDRESS`.

---

## 4. Roles, team mint, team sell lock, metadata

1. Grant NFT `FORGE_ROLE` to forge; grant B20 `MINT_ROLE`/`BURN_ROLE` to curve and forge.
2. `MintBerylBitsTeamAllocation` — mint `25` team tokens, revoke temporary mint role.
3. `curve.setTeamSellLock(TEAM_ADDRESS, 1000)`.
4. `ConfigureBerylBitsB20Metadata` — issuer metadata (contracts, team wallet, allocation, team_sell_lock).

```bash
# team sell lock (after team mint)
cast send --rpc-url "$BASE_MAINNET_RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY" \
  "$CURVE_PROXY_ADDRESS" 'setTeamSellLock(address,uint256)' "$TEAM_ADDRESS" 1000

forge script script/ConfigureBerylBitsB20Metadata.s.sol:ConfigureBerylBitsB20Metadata \
  --rpc-url "$BASE_MAINNET_RPC_URL" --broadcast --private-key "$DEPLOYER_PRIVATE_KEY"
```

---

## 5. Onchain verification

```bash
C="$CURVE_PROXY_ADDRESS"
cast call --rpc-url "$BASE_MAINNET_RPC_URL" "$C" 'BUY_FEE_BPS()(uint256)'          # 800
cast call --rpc-url "$BASE_MAINNET_RPC_URL" "$C" 'SELL_PAYOUT_BPS()(uint256)'      # 9200
cast call --rpc-url "$BASE_MAINNET_RPC_URL" "$C" 'quoteBuy(uint256)(uint256)' 1    # 0.0005 ETH
cast call --rpc-url "$BASE_MAINNET_RPC_URL" "$C" 'quoteSell(uint256)(uint256)' 1   # 0.00046 ETH
cast call --rpc-url "$BASE_MAINNET_RPC_URL" "$C" 'teamSellUnlockUnits()(uint256)'  # 1000
```

---

## 6. Mainnet smoke (minimum size)

`buy(1) → forge(1) → redeemAndSell([id], minPayout)`. Confirm: no stuck B20 in forge, NFT minted/burned cleanly, ETH returned.

---

## 7. Flip the frontend to mainnet

The frontend is network-agnostic — **no code change needed**, only env. In Vercel set Production env and redeploy:

```
VITE_CHAIN_ID=8453
VITE_RPC_URL=https://mainnet.base.org        # optional override
VITE_B20_TOKEN_ADDRESS=<mainnet B20>
VITE_CURVE_ADDRESS=<mainnet curve proxy>
VITE_FORGE_ADDRESS=<mainnet forge proxy>
VITE_NFT_ADDRESS=<mainnet nft proxy>
VITE_NFT_START_BLOCK=<curve/nft deploy block>
VITE_TEAM_ALLOCATION=25
VITE_PROJECT_URI=https://berylbits.xyz
VITE_RAINBOW_PROJECT_ID=<production WalletConnect id>
VITE_WALLETCONNECT_PROJECT_ID=<production WalletConnect id>
```

Explorer links and the wrong-network guard switch to mainnet automatically from `VITE_CHAIN_ID`.

---

## 8. Go / No-Go

**Go:** `forge test --offline` passes · `npm run build` passes · `isActivated(base.b20_asset)==true` · `isB20(token)==true` · curve/forge hold B20 mint+burn · temporary mint role revoked · economics return `800 / 9200 / 0.0005 / 0.00046` · `teamSellUnlockUnits==1000` · smoke clean.

**No-Go:** activation/factory check fails · insufficient deployer ETH · metadata URL down · role checks fail or temp mint role still active · smoke fails on buy/forge/redeem/sell.

---

## Post-launch

- Rotate the GitHub token shared during setup.
- Consider Safe/timelock migration for admin/upgrade/treasury (recommended hardening, not current decision).
