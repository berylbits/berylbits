# Beryl Bits Roadmap

## Current Status — Phase 5

Testnet implementation is complete. The project is now in `Phase 5 — Mainnet Readiness`.

Completed:

- Product, architecture, and roadmap docs exist.
- Foundry contract project is implemented.
- Upgradeable curve, forge, NFT, and legacy team vesting contracts are implemented.
- Native B20 test deployment exists.
- Bonding curve, forge, redeem, redeem-and-sell, pause, role, rescue, SVG, and direct team allocation tests have passed locally.
- Base testnet deployment exists with curve, forge, NFT, B20 asset, and historical vesting addresses.
- Frontend exists with RainbowKit wallet connection.
- Frontend has `Trade`, `Forge`, `Redeem`, `Docs`, and `System` tabs.
- Frontend copy now treats B20 as the standard, not the token name.
- Frontend redeem tab has NFT owner scanning fallback.
- RainbowKit app id is configured through `VITE_RAINBOW_PROJECT_ID` with `VITE_WALLETCONNECT_PROJECT_ID` as fallback.
- Treasury is currently configured as the deployer wallet.
- Final address policy is currently deployer wallet for treasury, admin, multisig, timelock, and team beneficiary.
- Latest testnet smoke passed on `2026-06-26`: `buy -> forge -> redeemAndSell` and `buy -> forge -> redeem -> sell`.
- Latest Sepolia redeploy uses native B20 `0xB20000000000000000000069d62bC417C3c5ca7E`, curve `0x5A0Ee112843DdA023b778c77cffb9904407188E0`, forge `0x272d1CBdf4f8D7091A958Af28746990a921BBd68`, and NFT `0x3848C9d288bef5083Ea6ca6C5262C7763559d427`.
- Latest Sepolia economics verified onchain after curve upgrade: first buy `0.0005 ETH`, first sell payout `0.00046 ETH`, buy fee `800 bps`, sell payout `9200 bps`, public cap `9,975`.
- Old Sepolia proxy B20 mint/burn roles were revoked; deployer temporary mint role was also revoked after the `25` token team mint.
- Latest smoke ended with deployer holding two live crystal NFTs after the final economics upgrade.
- Pashov-style AI security review high-confidence findings were patched locally: live-supply NFT cap, admin-only `initializeV2`, and non-upgradeable forge reentrancy guard.
- V3 upgrade shipped to Sepolia on `2026-06-26`: curve team sell lock added (`setTeamSellLock`), `forgeWithPermit` removed from forge. New curve impl `0x10455EC9A64D20CcA736d2a92B67c6BE55e8624a`, forge impl `0x979215246711b24594276216790e4e9B2a378819`.
- V3 E2E verified onchain: team sell reverts `TeamSellLocked` below the unlock threshold and succeeds once public demand reaches it; `forgeWithPermit` selector now reverts; forge `curve()` storage preserved; full buy/forge/redeem/sell regression smoke passed.
- `2026-06-28` mainnet-prep pass: added `uint256[48] __gap` to `BerylBitsUpgradeableBase`; added `GrantBerylBitsB20Roles.s.sol` (the previously-manual B20 mint/burn role grant); pointed `b20-readiness.sh` at Base mainnet; ran a 12-agent pashov-style review (one credible-commitment finding on the team sell lock plus documented leads, no new blocker).
- `2026-06-28` fresh full Sepolia rehearsal (new B20 + new curve/forge/NFT proxies) verified end to end: team-wallet and a separately funded public-user wallet both ran buy → forge → redeem → sell / redeemAndSell; the 8-band price table matched spec exactly; multi-band buy pricing crossed bands correctly; `setMaxBuyUnitsPerWallet` enforced `WalletBuyCapExceeded`; and curve/forge/NFT pause-unpause all behaved. Confirmed live the buy-cap accounting gap (buys made while the cap is `0` are not tracked).
- Frontend buy panel simplified: fee/spread readouts removed from the Trade tab (fees documented only in the Docs tab) and trade size bounded per wallet (buy ≤ remaining cap, sell ≤ token balance, button disabled with a warning past the limit).

Not complete:

- Mainnet B20 deployment is not complete.
- Mainnet Safe/multisig and timelock are intentionally set to deployer wallet for now.
- Mainnet team wallet is intentionally set to deployer wallet.
- Mainnet contractURI and metadata hosting are not finalized.
- Mainnet role assignment and temporary mint role revocation are not executed because mainnet is not deployed yet.
- Frontend is not deployed to production hosting.
- Final mainnet smoke tests are not run.
- Independent human security review is still not complete.

## Phase 0 — Docs Freeze

- status: complete
- finalized product spec
- finalized architecture
- finalized roadmap
- locked the `1 token <-> 1 NFT` primitive
- locked `10,000` shared units and `25` direct team allocation

## Phase 1 — Project Bootstrap

- status: complete
- initialized Foundry project structure
- installed `forge-std`
- installed `openzeppelin-contracts`
- installed `base-std`
- set remappings and compile targets

## Phase 2 — B20 + Curve

- status: complete for testnet, pending final mainnet B20 execution
- implemented `BerylBitsB20Token` local shim
- implemented `BerylBitsB20CurveUpgradeable`
- added native B20 `contractURI` and Asset `extraMetadata` configuration path
- documented v1 policy gating as disabled
- added buy and sell tests
- added buy fee, sell payout, and excess rescue tests
- added slippage-protected buy/sell tests

## Phase 3 — Forge + NFT

- status: complete
- implemented `BerylBitsB20ForgeUpgradeable`
- implemented `BerylBitsB20NFTUpgradeable`
- implemented centered crystal-only onchain SVG
- added `1:1` forge and redeem tests
- added `redeemAndSell` tests
- added UUPS, pause, role, and rescue tests
- added direct team allocation tests

## Phase 4 — Sepolia

- status: complete for test environment
- created deployer wallet with `cast`
- shared fundable address
- deployed to Base testnet
- verified role wiring
- deployed historical vesting on testnet; current mainnet model is `25` direct team tokens
- ran smoke/read checks against deployed contracts
- inspected rendered tokens
- built frontend against deployed addresses
- upgraded curve economics to `800 bps` buy fee and `9200 bps` sell payout
- verified final Sepolia quotes: `quoteBuy(1)=0.0005 ETH`, `quoteSell(1)=0.00046 ETH`

Remaining in Phase 4:

- Optional: manually open the frontend with the deployer wallet and confirm current owned token IDs render in the Redeem tab.
- Optional: rerun smoke once more after any contract or frontend RPC logic change.

## Phase 5 — Mainnet Readiness

- status: active
- final treasury address set to deployer wallet
- final admin/multisig address set to deployer wallet
- final timelock address set to deployer wallet
- final team wallet set to deployer wallet
- final economics set to `0.0005 ETH` first buy, `800 bps` buy fee, and `9200 bps` sell payout
- finalize contractURI and metadata host
- prepare final mainnet deploy params
- verify operational checklist
- confirm B20 mainnet availability and activation path
- run B20 readiness script: activation, `isB20`, and role checks
- dry-run mainnet deploy scripts with final env values
- run final local test suite before broadcast
- rerun pashov-style review on final mainnet code
- execute mainnet deploy
- verify roles and revoke temporary deployer permissions
- run mainnet smoke: `buy -> forge -> redeemAndSell`

Current decision notes:

- Treasury is deployer wallet by user decision.
- Admin, multisig, timelock, and team beneficiary are deployer wallet by user decision.
- Safer recommended treasury/admin remains a Safe multisig, but that is not the current decision.
- User-facing copy should say `Beryl Bits token`, not `B20 token`.

## Phase 6 — Post-Launch Backlog

- season system
- collectible upgrades
- crafting or merge mechanics
- rarity-aware secondary features
- analytics dashboard

## Immediate Next Checklist

1. Confirm final mainnet RPC endpoint and deployer wallet ETH balance.
2. Confirm final `B20_CONTRACT_URI`, project domain, and public metadata URLs.
3. Prepare mainnet `.env` with deployer wallet for treasury, admin/multisig, timelock, and team beneficiary.
4. Deploy the native Base B20 asset with supply cap `10,000 ether`.
5. Deploy the UUPS curve, forge, and NFT proxy set.
6. Grant B20 `MINT_ROLE` and `BURN_ROLE` to curve and forge via `GrantBerylBitsB20Roles.s.sol` (`base-forge --skip-simulation`).
7. Configure B20 metadata: NFT contract, forge contract, curve contract, team wallet, and team allocation.
8. Direct-mint `25` off-curve team tokens to deployer/team wallet (run `MintBerylBitsTeamAllocation` with `--slow`), then revoke temporary deployer mint role.
9. Call `curve.setTeamSellLock(TEAM_ADDRESS, unlockUnits)` with the chosen mainnet unlock threshold.
10. Verify economics onchain: buy fee `800 bps`, sell payout `9200 bps`, `quoteBuy(1)=0.0005 ETH`, `quoteSell(1)=0.00046 ETH`.
11. Run B20 readiness checks: activation, `isB20`, and curve/forge role checks.
12. Run mainnet smoke with minimum size: `buy -> forge -> redeemAndSell`.
13. Deploy frontend with mainnet addresses only after smoke passes.

## Mainnet Go/No-Go

Go conditions:

- `forge test --offline` passes.
- `npm run build` passes.
- B20 mainnet activation is available.
- `B20Factory.isB20(mainnetToken) == true`.
- Curve/forge have native B20 mint and burn roles.
- Temporary deployer mint role is revoked after the `25` token team mint.
- Onchain economics return `BUY_FEE_BPS=800`, `SELL_PAYOUT_BPS=9200`, `quoteBuy(1)=0.0005 ETH`, and `quoteSell(1)=0.00046 ETH`.
- Mainnet smoke completes with no stuck B20 in forge and no unexpected NFT ownership issue.

No-go conditions:

- B20 activation or factory verification fails.
- Deployer wallet has insufficient Base ETH for deploy plus smoke.
- Mainnet metadata URL is not available.
- Role checks fail or temporary mint role remains active unexpectedly.
- Smoke test fails on buy, forge, redeem, or redeem-and-sell.
