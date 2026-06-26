# Beryl Bits Product Spec

## Summary

Beryl Bits is a Base-native collectible primitive with one shared economic unit. A unit can exist as either a fungible Beryl Bits token, implemented with the B20 standard, or a `Beryl Bits NFT`, and users can move between those two forms at a strict `1 token <-> 1 NFT` ratio.

The user-facing flow is:

- Buy Beryl Bits tokens with ETH on a bonding curve.
- Burn `1 token` to forge `1 NFT`.
- Burn `1 NFT` to restore `1 token`.
- Sell Beryl Bits tokens back into the bonding curve for ETH.

The project takes inspiration from Unipeg's idea that trading activity can become a generative onchain collectible event. The difference is that Beryl Bits does not require a Uniswap v4 hook or an LP-funded pool; liquidity comes from a protocol-owned bonding curve.

## Lore

Beryl Bits are crystallized fragments of Base's Beryl era. Each NFT is a compact onchain beryl stone: faceted, centered, pixel-rendered, and generated fully by contract code.

The collection should feel like Base-native mineral artifacts, not PFP characters. There are no eyes, faces, antennae, mascot limbs, text, or character props inside the image.

## Economic Model

- Total shared supply cap: `10,000`.
- Public curve capacity: `9,975`.
- Team allocation: `25 tokens` minted directly to the deployer/team wallet before public launch.
- Forge ratio: `1 token = 1 NFT`.
- Redeem ratio: `1 NFT = 1 token`.
- B20 policy gating: disabled in v1.
- Native B20 contract URI and issuer metadata: enabled.

Team tokens are immediately fungible because the current launch decision removes vesting. The full `25 token` allocation is minted directly to `TEAM_ADDRESS`, currently the deployer wallet. The mint script grants a temporary mint role, mints the allocation, then revokes that temporary role.

## Bonding Curve Price Mechanics

The bonding curve price does not increase with time by itself. It increases only when net public curve demand increases `marketOutstandingUnits`.

Buy bands:

| Public units sold | Buy price per token |
| --- | ---: |
| `0-1,000` | `0.0005 ETH` |
| `1,001-2,500` | `0.00075 ETH` |
| `2,501-4,500` | `0.00125 ETH` |
| `4,501-7,000` | `0.002 ETH` |
| `7,001-9,975` | `0.003 ETH` |

Sell payout is `92%` of the matching active sell band. Example: if the current sell band price is `0.003 ETH`, the user receives `0.00276 ETH` per token before gas.

Important implications:

- Buys push the curve forward and can move the next buyers into higher price bands.
- Sells move the curve backward and can move the system into lower payout/buy bands.
- Forge does not move the curve because the public unit is still outstanding, only transformed from token into NFT.
- Redeem does not move the curve because the public unit is still outstanding, only transformed from NFT back into token.
- NFTs do not have a separate guaranteed ETH floor. Their curve exit path is `NFT -> token -> sell token`.
- UI should use slippage-protected curve calls: `buy(unitCount, maxCost)`, `sell(unitCount, minPayout)`, and `redeemAndSell(tokenIds, minPayout)`.
- `25` team units are minted off-curve to the deployer/team wallet; `9,975` units remain available for public curve entry.

## How Users Can Earn

Users can potentially earn in three ways:

- Curve appreciation: a user buys tokens in a lower band and later sells after enough net demand has moved the curve into a higher band. Because sell payout is `92%`, the later sell band must be high enough to overcome the spread and gas.
- NFT secondary sales: a user forges `1 token` into `1 NFT` and sells the NFT on a marketplace. The buyer is effectively buying a crystal collectible that can always be redeemed into `1 token`, but marketplace price can be above or below the curve value.
- Rarity/art premium: certain crystal traits, token IDs, or classes may trade at a premium on secondary markets. This is social/collector demand, not a protocol payout.

Users do not earn from:

- Holding alone if no new net curve demand arrives.
- Forging alone, because forge is a `1:1` form change.
- Redeeming alone, because redeem is also a `1:1` form change.
- A guaranteed treasury floor; the protocol does not promise one.

Simple example:

- Alice buys `1 token` at `0.0005 ETH`.
- `0.00004 ETH` goes to treasury as the `8%` buy fee.
- `0.00046 ETH` remains in the curve as sell backing.
- If Alice immediately sells, she receives `0.00046 ETH`.
- If later net demand moves the curve to the `0.00075 ETH` sell band, Alice's sell quote becomes `0.00069 ETH`.
- In that case Alice can be profitable before gas, because the curve moved up enough to exceed the initial buy price.

## Revenue Model

Treasury/deployer revenue comes from the bonding curve:

- Buy fee: `800 bps`, paid directly to treasury on each curve buy.
- Sell payout: `9200 bps` of the active band price.
- Forge fee: `0`.
- Redeem fee: `0`.

The sell spread is not separately transferred to treasury during sell; it is reflected in the lower payout and remains part of curve accounting.

Current testnet treasury configuration:

- Treasury address: deployer wallet.
- Deployer wallet receives buy fees directly from curve buys.
- Current mainnet decision: treasury remains deployer wallet.
- Safer alternative for a later hardening phase: move treasury/admin to a multisig.

## Art Direction

NFT images are centered pixel-art beryl crystals:

- `320x320` SVG canvas.
- `16x16` logical grid.
- `20x20` rect pixels.
- Centered crystal bounding area around `x=5..10`, `y=3..12`.
- No SVG text.
- No `font-*` usage.
- No eyes, aura, antenna, face, limbs, or marker symbols.

Primary palette: Base blue, aquamarine, emerald, deep navy, white highlights. Rare palette accents include heliodor yellow, morganite pink, goshenite white, and red beryl.

## Trait System

Trait categories:

- `Beryl Color`
- `Cut`
- `Facet Pattern`
- `Inclusion`
- `Clarity`
- `Background`
- `Class`
- `Mythic`

Special classes:

- `Founder Bit`: token IDs `1-200`.
- `Signal Bit`: first `20` token IDs in each `500` token band after class calculation.
- `Standard Bit`: all other tokens.
- `Mythic`: approximately `1%`, determined by seed.

Class affects metadata only in v1; it does not add visual symbols or payout differences.

## What We Gain

- Clear primitive: one token can become one crystal and back.
- No LP bootstrap requirement.
- Fully onchain art and metadata.
- Curve-based treasury revenue.
- Upgradeable operational layer for emergency fixes, pause, and rescue.
- B20 issuer metadata through `contractURI` and Asset `extraMetadata`.
- Simple launch operations because treasury/admin/team beneficiary are all deployer wallet by current decision.

## What We Do Not Gain

- No hard ETH floor for NFTs.
- No treasury-backed redemption guarantee beyond `NFT -> token`.
- No fee income from forge or redeem.
- Team allocation is `25` direct-minted tokens.
- No allowlist/blocklist policy gating in v1.
- No freeze/seize or burn-blocked compliance flow in v1.
- No rebase multiplier, announcements, or batch mint in v1.
- No multisig/timelock hardening in the current mainnet decision; this can be added later.

## Security Review Status

Pashov-style AI review found mainnet-blocking issues that are now addressed in code:

- NFT forge capacity could be exhausted by lifetime `totalMinted` accounting. Resolution: cap checks now use live NFT supply.
- Upgradeable forge `initializeV2` could be called by anyone before admin initialization. Resolution: `initializeV2` is admin-gated and rejects zero curve addresses.
- Non-upgradeable forge could be reentered during safe mint callbacks. Resolution: forge, forgeWithPermit, and redeem now use `nonReentrant`.

Resolved after the latest review pass:

- `forgeWithPermit` is removed. Only the standard approve-and-forge path remains, eliminating the permit-nonce griefing vector.
- Team allocation now carries an on-chain sell lock: the team wallet cannot pull ETH from the curve until public `marketOutstandingUnits` reaches a configured unlock threshold (`setTeamSellLock`). This is a credible commitment that ETH backing exists before any team exit.

Remaining review leads:

- Trait randomness uses block-derived entropy and can be timing-influenced. This is acceptable for v1 only if rarity remains collectible metadata, not financial utility. Practical manipulation requires sequencer/block-producer cooperation, which is low risk on Base today.
- Current governance decision keeps deployer as final authority. Safer hardening remains Safe/timelock migration.

## Mainnet Positioning

Beryl Bits should be positioned as a Base-native token/NFT conversion primitive built on B20 with bonding-curve liquidity. It is not a generic PFP mint, not a pure memecoin, and not a treasury-backed bond.

## DApp Status

The current frontend is a lightweight tabbed app:

- `Trade`: buy/sell interface with percentage-based price protection.
- `Forge`: token approval and forge flow.
- `Redeem`: wallet crystal scanner, manual token ID fallback, redeem, and redeem-and-sell.
- `Docs`: short user-facing explanation of the primitive, curve, NFT generation, and risks.
- `System`: contract addresses and public state.

Wallet connection uses RainbowKit with project ID `3c7c133910c85aa281f3dc73f2ce2848`. The frontend reads `VITE_RAINBOW_PROJECT_ID` first and falls back to `VITE_WALLETCONNECT_PROJECT_ID`. The UI is still testnet-targeted internally, but visible copy should avoid over-emphasizing the testnet name unless needed for safety.

## B20 Issuer Metadata

The Base B20 asset should expose project metadata without adding transfer restrictions:

- `contractURI`: official offchain collection/token metadata document.
- `extraMetadata("project")`: `Beryl Bits`.
- `extraMetadata("primitive")`: `B20_TO_ONCHAIN_NFT_1_TO_1`.
- `extraMetadata("network")`: `Base`.
- `extraMetadata("policy_gating")`: `disabled_v1`.
- `extraMetadata("nft_contract")`: current NFT proxy address.
- `extraMetadata("forge_contract")`: current Forge proxy address.
- `extraMetadata("curve_contract")`: current Curve proxy address.
- `extraMetadata("team_wallet")`: current team/deployer wallet.
- `extraMetadata("team_allocation")`: `25`.
- `extraMetadata("team_sell_lock")`: `unlock_at_1000_public_units`.

`policy_gating = disabled_v1` means B20 transfers are open in v1. This is intentional because Beryl Bits is not a regulated stablecoin, RWA, or allowlisted sale product.

## X Bio

Primary bio:

`Base-native crystal primitive built on B20. Buy on the curve, forge fully onchain pixel beryl NFTs, redeem back 1:1. No floor promises.`

Shorter variant:

`Base-native crystal primitive. Buy on the curve, forge onchain pixel beryl, redeem 1:1.`

Positioning rules for social copy:

- Say `1 token <-> 1 NFT`, not separate token and NFT supplies.
- Say Beryl Bits is built on B20; do not use `B20` as the token name in user-facing copy.
- Say price moves with net curve demand, not with time.
- Do not imply guaranteed ETH floor, treasury-backed redemption, or passive yield.
- Keep the art language crystal/beryl-focused, not mascot or PFP-focused.
