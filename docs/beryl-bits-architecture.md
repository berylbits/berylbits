# Beryl Bits Architecture

## Summary

The production system uses a native Base `B20` token plus three UUPS upgradeable EVM contracts:

- `BerylBitsB20CurveUpgradeable`
- `BerylBitsB20ForgeUpgradeable`
- `BerylBitsB20NFTUpgradeable`

The native B20 asset itself is a Base precompile asset and is not upgradeable by this project. The upgradeable layer handles bonding curve issuance/sell-back, token/NFT conversion, onchain NFT metadata, pause controls, rescue controls, and future operational fixes.

## Current Deployment Status

Current status is Phase 5 mainnet readiness. The system has been deployed and smoke-tested on Base testnet with the following live addresses:

- Native B20 asset: `0xB20000000000000000000069d62bC417C3c5ca7E`
- Curve proxy: `0x5A0Ee112843DdA023b778c77cffb9904407188E0`
- Forge proxy: `0x272d1CBdf4f8D7091A958Af28746990a921BBd68`
- NFT proxy: `0x3848C9d288bef5083Ea6ca6C5262C7763559d427`
- Legacy testnet team vesting: `0x781a02c6E8E9AbB2aC71c1d8FE4B8434aD8903E5`
- Current treasury: deployer wallet `0xF00e1844903586a83a7A2d8ec28f4DCB5e31DeCa`

Current implementation state:

- UUPS curve, forge, and NFT contracts are implemented.
- B20 mint/burn roles are wired to curve and forge in the test deployment.
- Current mainnet team allocation is `25 tokens` minted directly to the deployer/team wallet. The vesting contract is historical testnet state only.
- Sepolia curve proxy was upgraded to the final `%8 buy fee / %92 sell payout` economics.
- Latest Sepolia smoke on this B20/proxy set confirmed `buy -> forge -> redeemAndSell` and `buy -> forge -> redeem -> sell`.
- Old Sepolia curve/forge B20 mint and burn roles were revoked after redeploy.
- Frontend uses RainbowKit with `VITE_RAINBOW_PROJECT_ID` configured and `VITE_WALLETCONNECT_PROJECT_ID` as fallback.
- Frontend includes trade, forge, redeem, docs, and system tabs.
- Redeem UI includes both wallet scanning and manual token ID fallback.

This deployment remains a test environment. Mainnet deployment should use fresh final addresses, final B20 asset configuration, and final governance role handoff.

## Components

### Native B20 Token

Responsibilities:

- Represent the fungible form.
- Enforce `10,000 ether` supply cap.
- Allow curve and forge to mint/burn through native B20 roles.
- Expose issuer metadata through `contractURI` and Asset `extraMetadata`.
- Keep B20 policy gating disabled in v1.

Role assignments:

- Curve proxy: `MINT_ROLE`, `BURN_ROLE`.
- Forge proxy: `MINT_ROLE`, `BURN_ROLE`.
- Mainnet admin/metadata/pause roles: deployer wallet by current user decision.
- Mainnet upgrade execution role: deployer wallet by current user decision.
- Current testnet treasury: deployer wallet.
- B20 `METADATA_ROLE`, `PAUSE_ROLE`, and `UNPAUSE_ROLE`: deployer wallet by current user decision.

Intentionally unused B20 features in v1:

- Policy registry allowlist/blocklist gating.
- `BURN_BLOCKED_ROLE` freeze-and-seize flow.
- Asset multiplier/rebase.
- Asset announcements.
- Asset batch mint.

These are kept out because they add compliance/issuer complexity that does not improve the `1 token <-> 1 NFT` primitive.

Team supply:

- `25` Beryl Bits token units are minted directly to `TEAM_ADDRESS` before public launch.
- Public curve capacity is `9,975`.
- `TEAM_ADDRESS` is the deployer wallet by current decision.
- No vesting contract, cliff, or claim flow is used in the current mainnet model.
- Team tokens are fungible and not separately ETH-backed.

### Curve

Responsibilities:

- Sell Beryl Bits tokens for ETH.
- Buy back Beryl Bits tokens for ETH.
- Apply step-curve pricing.
- Pay buy fee to treasury.
- Keep ETH backing for public sell obligations.
- Enforce the team sell lock until public demand reaches the unlock threshold.
- Enforce an optional fair-launch per-wallet buy cap (admin-configurable, `0` = unlimited).
- Rescue only excess ETH and wrong non-B20 ERC20 tokens.

Pricing:

- Buy bands (8, ceilings `1,250 / 2,500 / 3,750 / 5,000 / 6,250 / 7,500 / 8,750 / 9,975`): `0.0005 / 0.00065 / 0.00085 / 0.0011 / 0.0014 / 0.0018 / 0.0023 / 0.003 ETH`.
- Buy fee: `800 bps`, transferred to treasury.
- Sell payout: `9200 bps` of active band price.
- Public curve capacity: `9,975` units.
- Slippage-safe calls: `buy(unitCount, maxCost)` and `sell(unitCount, minPayout)`.
- Backward-compatible calls: `buy(unitCount)` and `sell(unitCount)`.

### Forge

Responsibilities:

- Burn Beryl Bits tokens and mint NFTs.
- Burn NFTs and mint Beryl Bits tokens.
- Keep conversion at exact `1:1`.
- Charge no forge/redeem fee in v1.
- Expose `redeemAndSell(tokenIds, minPayout)` as a one-transaction wrapper around `NFT -> token -> sell`.

### NFT

Responsibilities:

- Mint sequential ERC721-compatible NFTs.
- Burn NFTs during redeem.
- Track `totalMinted` and `liveSupply`.
- Produce fully onchain JSON and SVG.
- Pause transfers if needed.

Art rules:

- SVG uses rect-based pixel rendering.
- Crystal is centered on the canvas.
- No SVG text, font usage, eyes, face, aura, antenna, limbs, or marker symbols.

## State Transitions

### Buy

1. User sends ETH to curve.
2. Curve quotes price from `marketOutstandingUnits`.
3. Curve mints Beryl Bits tokens to user.
4. Curve sends `800 bps` buy fee to treasury.
5. Curve keeps remaining ETH as sell backing.
6. `marketOutstandingUnits` increases.

### Forge

1. User approves forge for Beryl Bits tokens.
2. Forge transfers Beryl Bits tokens from user.
3. Forge burns its token balance.
4. Forge mints the same quantity of NFTs.
5. `marketOutstandingUnits` does not change.

### Redeem

1. User submits owned NFT IDs.
2. Forge verifies ownership.
3. Forge burns NFTs.
4. Forge mints matching Beryl Bits tokens to user.
5. `marketOutstandingUnits` does not change.

### Sell

1. User approves curve for Beryl Bits tokens.
2. Curve quotes sell payout.
3. Curve transfers Beryl Bits tokens from user.
4. Curve burns its token balance.
5. Curve sends ETH payout to user.
6. `marketOutstandingUnits` decreases.

Direct `NFT -> ETH` sell is intentionally not implemented. Users redeem NFT to tokens first, then sell tokens to the curve.
`redeemAndSell` is a UX wrapper for the same path, not a separate economic primitive.

## Upgrade, Pause, And Rescue

Each upgradeable contract has:

- `DEFAULT_ADMIN_ROLE`
- `PAUSE_ROLE`
- `UPGRADER_ROLE`
- `RESCUE_ROLE`

Mainnet role policy:

- Deployer wallet holds pause/rescue/admin operations by current user decision.
- Deployer wallet holds upgrade execution by current user decision.
- Safer later hardening path: migrate admin/upgrade/pause/rescue to Safe multisig plus timelock.

Pause behavior:

- Curve pause blocks buy and sell.
- Forge pause blocks forge and redeem.
- NFT pause blocks transfers and approvals.

Rescue behavior:

- `rescueExcessETH(to, amount)` can only withdraw ETH above `quoteSell(marketOutstandingUnits)`.
- `rescueERC20(asset, to, amount)` can rescue wrong ERC20 tokens.
- The Base B20 asset cannot be rescued from the curve.
- Full admin withdrawal of user backing is not allowed.

## Security Assumptions

- Deployer admin is trusted for upgrades, pause, and bounded rescue.
- Buy fee is trusted treasury revenue.
- Team tokens are sent to the team wallet at launch through direct mint.
- Curve sell liquidity depends on ETH retained by buys plus any intentionally added excess ETH.

## Security Review Findings

Pashov-style AI review was run against the Solidity scope. High-confidence findings and resolutions:

- NFT lifetime mint cap could permanently starve forge capacity after repeated forge/redeem cycles. Resolution: NFT cap checks now use `liveSupply + quantity`, while `totalMinted` remains only the token ID counter.
- `BerylBitsB20ForgeUpgradeable.initializeV2` was an unprotected reinitializer. Resolution: it now requires `DEFAULT_ADMIN_ROLE` and rejects zero curve addresses.
- Non-upgradeable forge could reenter during ERC721 safe mint callback. Resolution: non-upgradeable forge now uses `ReentrancyGuard`.

Resolved after the latest review pass:

- `forgeWithPermit` permit-nonce griefing vector is removed. The forge contracts now expose only the standard approve-and-forge path, so there is no permit nonce for an attacker to pre-consume.
- `BerylBitsUpgradeableBase` now reserves a `uint256[48] __gap`. The base contract holds shared role/pause state inherited by curve, forge, and NFT; the gap lets it gain storage in a future upgrade without colliding with child-contract slots.

Latest multi-agent pass (12 specialty agents) — confirmed and triaged:

- The team sell lock is keyed on the ETH `payoutRecipient` and intentionally covers `sell`, `sellTo`, and `redeemAndSell`. It is a credible-commitment guard against the team wallet, not airtight against a malicious admin (who could route through another wallet); this is an accepted v1 stance.
- Treasury is fixed at `initialize` with no setter. A treasury that reverts on receive would brick buys until an upgrade. Accepted while treasury is the deployer EOA; a `setTreasury` is the recommended hardening if treasury ever becomes a contract.
- Buy-cap accounting gap (see Fair-Launch Buy Cap below): pre-cap buys are invisible once a cap is later enabled. Mitigated operationally by setting the cap before public buys.

Remaining leads to track before or after launch:

- Block-derived NFT trait entropy can be timing-influenced. Practical risk on Base is low because only the sequencer/block producer could bias it; accepted for v1 while rarity stays collectible metadata with no financial utility.
- Deployer-retained admin and upgrade roles are intentional for now but should be migrated to Safe/timelock if the launch risk posture changes.

## Team Sell Lock

The team allocation is `25` direct-minted, off-curve tokens with no separate ETH backing. To make the "team does not exit before there is real backing" stance a verifiable on-chain commitment rather than a promise, the curve enforces a team sell lock:

- `setTeamSellLock(teamWallet, unlockUnits)` (admin) records the team wallet and an unlock threshold expressed in public `marketOutstandingUnits`.
- A sell is reverted with `TeamSellLocked` when the ETH recipient is the configured team wallet and `marketOutstandingUnits < unlockUnits`.
- The check is keyed on the ETH `payoutRecipient`, so it covers direct `sell`, `sellTo`, and the `redeemAndSell` routing path uniformly.
- Setting `unlockUnits = 0` (or leaving `teamWallet` unset) disables the lock.
- Chosen threshold: `unlockUnits = 1000`. The team cannot pull ETH from the curve until the entire first buy band (`1,000` public units) is sold, i.e. until at least ~`0.46 ETH` of public sell backing exists in the curve.

This guarantees that enough public ETH backing has accumulated in the curve before the team can pull any ETH out. It is a credible-commitment mechanism, not airtight security against a malicious admin: the deployer retains upgrade/admin rights and could route a sale through a different wallet, which would be publicly visible and defeat the point.

## Fair-Launch Buy Cap

The curve supports an optional per-wallet buy cap to slow one-transaction sweeps and bots at launch:

- `setMaxBuyUnitsPerWallet(maxUnits)` (admin) sets the cap in units; `0` disables it (unlimited).
- `curveBoughtUnits[wallet]` tracks cumulative curve-bought units per wallet; `_buy` reverts `WalletBuyCapExceeded` past the cap.
- Applies only to curve buys (forge/redeem/team off-curve mint are unaffected).
- It is a soft, sybil-imperfect speed bump (a whale can split across wallets), best paired with frontend friction if stricter fairness is needed. Typically set tight at launch (e.g. `25`) and lifted once initial demand settles.
- **Tracking gap:** `curveBoughtUnits` is only written when a cap is active (`maxBuyUnitsPerWallet > 0`). Buys made while the cap is `0` are never recorded, so enabling a cap afterward grants those wallets a fresh full quota. Set the cap before opening public buys. Verified live on Sepolia (`2026-06-28`): after cap-less buys `curveBoughtUnits` read `0`; once a cap was set, subsequent buys tracked and `WalletBuyCapExceeded` fired at the limit.

## Public Communication Constraints

- Public copy must not describe the NFT as having a guaranteed ETH floor.
- Public copy must not imply that forge or redeem creates profit by itself.
- Public copy should describe `redeemAndSell` as a UX wrapper for `NFT -> token -> ETH`, not as a separate direct NFT liquidation primitive.
- X bio and launch copy should use the phrase `token-to-relic primitive` or equivalent wording to avoid positioning Beryl Bits as a generic PFP mint.
- User-facing copy should call the fungible asset `Beryl Bits token` or `token`, not `B20`. B20 is the underlying Base token standard.

## Frontend Architecture

The frontend is a Vite, React, TypeScript app with wagmi, viem, and RainbowKit. It intentionally avoids a heavy UI framework.

Frontend responsibilities:

- Connect wallet through RainbowKit.
- Restrict interaction to the configured chain.
- Read quotes, balances, supplies, allowances, team allocation, and team wallet state.
- Execute slippage-safe `buy(unitCount, maxCost)` and `sell(unitCount, minPayout)`.
- Combine approve and forge into a single user-facing forge action.
- Load owned NFTs by Transfer logs, with `ownerOf` scanning fallback when RPC log queries fail.
- Preview onchain SVG from `imageSVG(tokenId)`.
- Keep private keys out of frontend env files.

Trade-panel UX rules:

- The Trade panel is intentionally minimal: it shows the input, the slippage-protected output quote, and price-protection controls. The fee/spread details (8% buy fee, 92% sell payout, round-trip cost) live only in the `Docs` tab, not repeated on every trade — the buy/sell surface stays clean.
- Trade size is bounded per wallet. A buy is capped at the wallet's remaining curve allowance (`maxBuyUnitsPerWallet - curveBoughtUnits`, falling back to `25` when no on-chain cap is set); a sell is capped at the wallet's token balance. Exceeding the limit shows an inline alert and disables the buy/sell button, so a user cannot submit a transaction the contract would reject.

Current frontend env:

- `VITE_RAINBOW_PROJECT_ID=3c7c133910c85aa281f3dc73f2ce2848`
- `VITE_WALLETCONNECT_PROJECT_ID=3c7c133910c85aa281f3dc73f2ce2848`
- Public contract addresses only.
- No deployer private key.

## Deployment Order

1. Create native B20 with `10,000 ether` supply cap.
2. Set B20 `contractURI` and initial issuer metadata.
3. Deploy UUPS implementations.
4. Deploy ERC1967 proxies with initializer calldata.
5. Grant NFT `FORGE_ROLE` to forge proxy (done inside `DeployBerylBitsUpgradeableSystem.s.sol`).
6. Run `GrantBerylBitsB20Roles.s.sol` to grant native B20 `MINT_ROLE` and `BURN_ROLE` to curve and forge proxies (requires `base-forge --skip-simulation`).
7. Run `MintBerylBitsTeamAllocation.s.sol` to mint `25` Beryl Bits tokens for `TEAM_ADDRESS` (use `--slow`; the script does grant→mint→revoke and is sensitive to nonce races).
8. Call `curve.setTeamSellLock(TEAM_ADDRESS, unlockUnits)` to enable the team sell lock.
9. Verify the temporary team mint role is revoked.
10. Assign deployer wallet admin/upgrade/pause/rescue roles for current mainnet decision.
11. Configure B20 metadata/extraMetadata with final contract addresses.
12. Run B20 readiness checks: activation, `isB20`, and curve/forge roles.
13. Run smoke: `buy(maxCost) -> forge -> redeemAndSell(minPayout)`.
14. Confirm SVG is centered, text-free crystal art.

## Mainnet Blockers

Before mainnet, these must be finalized:

- Final B20 activation availability and mainnet B20 deployment path.
- Final treasury address is deployer wallet by current decision.
- Final admin, multisig, timelock, and team wallet are deployer wallet by current decision.
- Final contractURI and offchain metadata URL.
- Final public launch copy and risk language.
- Final Base mainnet RPC endpoint and deployer wallet ETH balance.
- Final deploy script parameters for mainnet.
- Final role checklist should document which deployer permissions are intentionally retained.
