# Beryl Bits

**Base-native crystal primitive built on B20.** Buy on the bonding curve, forge fully onchain pixel beryl NFTs, redeem back 1:1. No floor promises.

Beryl Bits is a token/NFT conversion primitive on [Base](https://base.org). One shared economic unit can exist as either a fungible **Beryl Bits token** (implemented with the native **B20** standard) or a **Beryl Bits NFT**, and users move between the two forms at a strict `1 token ↔ 1 NFT` ratio. Liquidity comes from a protocol-owned bonding curve — no Uniswap hook, no LP bootstrap.

- **Website:** https://berylbits.xyz
- **Network:** Base (B20 asset standard)

---

## How it works

```
   ETH ──buy──▶ Beryl Bits token ──forge──▶ Crystal NFT
   ETH ◀─sell── Beryl Bits token ◀─redeem── Crystal NFT
```

- **Buy / Sell** tokens against a stepped bonding curve.
- **Forge** burns `1 token` to mint `1 NFT` (fully onchain SVG art).
- **Redeem** burns `1 NFT` to restore `1 token`.
- **redeemAndSell** is a one-tx UX wrapper for `NFT → token → ETH`.

NFTs have **no guaranteed ETH floor**. Their only curve exit path is `NFT → token → sell`.

---

## Economic model

| Parameter | Value |
|---|---|
| Total shared supply cap | `10,000` |
| Public curve capacity | `9,975` |
| Team allocation (direct mint, off-curve) | `25` |
| Forge ratio | `1 token = 1 NFT` |
| Buy fee → treasury | `800 bps` (8%) |
| Sell payout | `9200 bps` (92%) of active band |
| Forge / redeem fee | `0` |

### Bonding curve bands

| Public units sold | Buy price / token |
|---|---:|
| `0 – 1,250` | `0.0005 ETH` |
| `1,251 – 2,500` | `0.00065 ETH` |
| `2,501 – 3,750` | `0.00085 ETH` |
| `3,751 – 5,000` | `0.0011 ETH` |
| `5,001 – 6,250` | `0.0014 ETH` |
| `6,251 – 7,500` | `0.0018 ETH` |
| `7,501 – 8,750` | `0.0023 ETH` |
| `8,751 – 9,975` | `0.003 ETH` |

Price moves with **net curve demand**, not with time. Forge and redeem do not move the curve (the public unit stays outstanding, only its form changes).

### Team sell lock

The team allocation is direct-minted and not separately ETH-backed. As a credible on-chain commitment, the curve enforces a **team sell lock**: the team wallet cannot pull ETH out of the curve until public demand reaches **`1,000` outstanding units** (the full first band). The check is keyed on the ETH recipient, so it covers `sell`, `sellTo`, and `redeemAndSell`.

---

## Architecture

Native B20 asset + three UUPS-upgradeable contracts:

| Contract | Responsibility |
|---|---|
| `BerylBitsB20CurveUpgradeable` | Bonding-curve buy/sell, buy fee, ETH backing, team sell lock, bounded rescue |
| `BerylBitsB20ForgeUpgradeable` | `1:1` token↔NFT forge/redeem, `redeemAndSell` wrapper |
| `BerylBitsB20NFTUpgradeable` | Sequential ERC-721, fully onchain JSON + pixel-crystal SVG |
| Native **B20** token | Fungible unit; mint/burn roles granted to curve and forge |

Each upgradeable contract has `DEFAULT_ADMIN_ROLE`, `PAUSE_ROLE`, `UPGRADER_ROLE`, and `RESCUE_ROLE`. Rescue can only withdraw ETH above curve liability and wrong (non-B20) ERC-20s — never user backing.

See [`docs/`](docs/) for the full product spec, architecture, and roadmap.

---

## Repository layout

```
src/         Solidity contracts (upgradeable + local shim)
script/      Foundry deploy / upgrade / config scripts
test/        Foundry test suites
frontend/    Vite + React + TypeScript + wagmi/viem/RainbowKit dApp
docs/        Product spec, architecture, roadmap
deployments/ Recorded testnet addresses and tx hashes
```

---

## Build & test

```bash
# Contracts (standard Foundry, offline)
forge build --offline
forge test  --offline

# Frontend
cd frontend
npm install
npm run build
npm run dev
```

---

## Deployment (Base)

> **B20 note:** the native B20 asset is created through the Base factory **precompile** at `0xB20f000000000000000000000000000000000000`. Standard Foundry cannot simulate precompile calls — use Base's fork (`base-foundryup` → `base-forge` / `base-cast`) with `--skip-simulation` for B20 creation. B20 must be **activated** on-chain (check the Activation Registry at `0x8453000000000000000000000000000000000001`) before creation.

High-level order:

1. `CreateBerylBitsB20Token` — create the B20 asset (supply cap `10,000`, contractURI, extraMetadata).
2. Deploy UUPS curve / forge / NFT implementations + proxies.
3. Grant NFT `FORGE_ROLE` to forge; grant B20 `MINT_ROLE` / `BURN_ROLE` to curve and forge.
4. `MintBerylBitsTeamAllocation` — mint `25` team tokens, then revoke the temporary mint role.
5. `curve.setTeamSellLock(TEAM_ADDRESS, 1000)` — enable the team sell lock.
6. `ConfigureBerylBitsB20Metadata` — set issuer metadata (contract addresses, team allocation, team sell lock).
7. Smoke: `buy → forge → redeemAndSell`.

The `UpgradeBerylBits*` scripts handle in-place implementation upgrades for the existing proxies.

---

## Security

- Pashov-style AI review resolved: live-supply NFT cap, admin-gated `initializeV2`, non-upgradeable forge reentrancy guard, and removal of `forgeWithPermit` (permit-nonce griefing).
- Trait randomness uses block-derived entropy — accepted for v1 (rarity is collectible metadata, not financial utility; practical bias requires sequencer cooperation).
- Admin/upgrade roles are deployer-held by current decision; Safe/timelock migration is the recommended later hardening.

**No private keys or secrets are committed.** `.env*`, `.keystores/`, and key material are gitignored.

---

## License

MIT
