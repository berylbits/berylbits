import { useEffect, useMemo, useRef, useState, type MouseEvent as ReactMouseEvent } from 'react';
import { formatEther, parseAbiItem, parseEther, zeroAddress, type Address } from 'viem';
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { explorer, contracts } from './config';
import { curveAbi, erc20Abi, forgeAbi, nftAbi } from './abis';

const unit = parseEther('1');
const modes = ['buy', 'forge', 'redeem', 'docs', 'system'] as const;
type Mode = (typeof modes)[number];
type TradeSide = 'buy' | 'sell';

const curveBands = [
  { end: 1250, price: 0.0005 },
  { end: 2500, price: 0.00065 },
  { end: 3750, price: 0.00085 },
  { end: 5000, price: 0.0011 },
  { end: 6250, price: 0.0014 },
  { end: 7500, price: 0.0018 },
  { end: 8750, price: 0.0023 },
  { end: 9975, price: 0.003 },
];

function bandIndexForUnits(value: number) {
  const index = curveBands.findIndex((band) => value <= band.end);
  return index === -1 ? curveBands.length - 1 : index;
}

function units(value: string) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return 0n;
  return BigInt(Math.floor(parsed));
}

function ids(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => BigInt(item));
}

function eth(value?: bigint, digits = 5) {
  if (value === undefined) return '...';
  return Number(formatEther(value)).toLocaleString(undefined, { maximumFractionDigits: digits });
}

function bandPrice(value: number) {
  return value.toLocaleString(undefined, {
    minimumFractionDigits: value < 0.001 ? 4 : 3,
    maximumFractionDigits: 5,
  });
}

function percent(value: string) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return Math.min(parsed, 50);
}

function withSlippageUp(value: bigint, bps: bigint) {
  return (value * (10_000n + bps)) / 10_000n;
}

function withSlippageDown(value: bigint, bps: bigint) {
  return (value * (10_000n - bps)) / 10_000n;
}

export function App() {
  const [mode, setMode] = useState<Mode>('buy');
  const [tradeSide, setTradeSide] = useState<TradeSide>('buy');
  const [tradeCount, setTradeCount] = useState('1');
  const [forgeCount, setForgeCount] = useState('1');
  const [tokenIds, setTokenIds] = useState('');
  const [previewId, setPreviewId] = useState('5');
  const [priceProtection, setPriceProtection] = useState('1');
  const [ownedTokenIds, setOwnedTokenIds] = useState<bigint[]>([]);
  const [ownedSvgs, setOwnedSvgs] = useState<Record<string, string>>({});
  const [pendingApproval, setPendingApproval] = useState<'curve' | 'forge' | null>(null);
  const [curveAllowanceOverride, setCurveAllowanceOverride] = useState<bigint | null>(null);
  const [forgeAllowanceOverride, setForgeAllowanceOverride] = useState<bigint | null>(null);

  const selectedIds = useMemo(() => ids(tokenIds), [tokenIds]);
  const selectedSet = useMemo(() => new Set(selectedIds.map((id) => id.toString())), [selectedIds]);
  const selectedIdCount = BigInt(Math.max(selectedIds.length, 1));
  const tradeUnits = units(tradeCount);
  const forgeUnits = units(forgeCount);
  const protectionValue = percent(priceProtection);
  const slippageBps = BigInt(Math.round(protectionValue * 100));
  const previewTokenId = previewId.trim() ? BigInt(previewId) : 1n;

  const { address, chainId, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { data: hash, error, isPending: writing, writeContract } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data, refetch } = useReadContracts({
    allowFailure: true,
    contracts: [
      { address: contracts.curve, abi: curveAbi, functionName: 'quoteBuy', args: [tradeUnits || 1n] },
      { address: contracts.curve, abi: curveAbi, functionName: 'quoteSell', args: [tradeUnits || 1n] },
      { address: contracts.curve, abi: curveAbi, functionName: 'quoteSell', args: [selectedIdCount] },
      { address: contracts.curve, abi: curveAbi, functionName: 'marketOutstandingUnits' },
      { address: contracts.curve, abi: curveAbi, functionName: 'PUBLIC_UNITS' },
      { address: contracts.b20, abi: erc20Abi, functionName: 'totalSupply' },
      { address: contracts.nft, abi: nftAbi, functionName: 'liveSupply' },
      { address: contracts.nft, abi: nftAbi, functionName: 'totalMinted' },
      { address: contracts.curve, abi: curveAbi, functionName: 'teamSellUnlockUnits' },
      ...(address
        ? [
            { address: contracts.b20, abi: erc20Abi, functionName: 'balanceOf', args: [address] },
            { address: contracts.b20, abi: erc20Abi, functionName: 'allowance', args: [address, contracts.forge] },
            { address: contracts.b20, abi: erc20Abi, functionName: 'allowance', args: [address, contracts.curve] },
            { address: contracts.nft, abi: nftAbi, functionName: 'balanceOf', args: [address] },
          ]
        : []),
    ] as any,
  });

  const { data: svg } = useReadContract({
    address: contracts.nft,
    abi: nftAbi,
    functionName: 'imageSVG',
    args: [previewTokenId],
    query: { enabled: previewId.trim().length > 0 },
  });

  useEffect(() => {
    setCurveAllowanceOverride(null);
    setForgeAllowanceOverride(null);
  }, [address]);

  const quoteBuy = data?.[0]?.result as bigint | undefined;
  const quoteSell = data?.[1]?.result as bigint | undefined;
  const redeemQuote = data?.[2]?.result as bigint | undefined;
  const outstanding = data?.[3]?.result as bigint | undefined;
  const publicCap = data?.[4]?.result as bigint | undefined;
  const totalSupply = data?.[5]?.result as bigint | undefined;
  const liveSupply = data?.[6]?.result as bigint | undefined;
  const totalMinted = data?.[7]?.result as bigint | undefined;
  const teamSellUnlockUnits = data?.[8]?.result as bigint | undefined;
  const b20Balance = data?.[9]?.result as bigint | undefined;
  const forgeAllowance = data?.[10]?.result as bigint | undefined;
  const curveAllowance = data?.[11]?.result as bigint | undefined;
  const nftBalance = data?.[12]?.result as bigint | undefined;
  const effectiveForgeAllowance: bigint | undefined =
    forgeAllowanceOverride !== null && forgeAllowanceOverride > (forgeAllowance ?? 0n) ? forgeAllowanceOverride : forgeAllowance;
  const effectiveCurveAllowance: bigint | undefined =
    curveAllowanceOverride !== null && curveAllowanceOverride > (curveAllowance ?? 0n) ? curveAllowanceOverride : curveAllowance;

  const wrongNetwork = isConnected && chainId !== contracts.chainId;
  const busy = writing || confirming;
  const maxCost = quoteBuy === undefined ? 0n : withSlippageUp(quoteBuy, slippageBps);
  const minSell = quoteSell === undefined ? 0n : withSlippageDown(quoteSell, slippageBps);
  const minRedeemSell = redeemQuote === undefined ? 0n : withSlippageDown(redeemQuote, slippageBps);
  const forgeAmount = forgeUnits * unit;
  const needsForgeApproval = forgeAmount > 0n && (effectiveForgeAllowance ?? 0n) < forgeAmount;
  const sellAmount = tradeUnits * unit;
  const needsCurveApproval = sellAmount > 0n && (effectiveCurveAllowance ?? 0n) < sellAmount;
  const activeTradeQuote = tradeSide === 'buy' ? quoteBuy : quoteSell;
  const buyTreasuryFee = quoteBuy === undefined ? undefined : (quoteBuy * BigInt(800)) / 10_000n;
  const immediateSellValue = quoteSell;
  const roundTripLoss =
    quoteBuy === undefined || quoteSell === undefined || quoteBuy <= quoteSell
      ? undefined
      : ((quoteBuy - quoteSell) * 10_000n) / quoteBuy;
  const busyButtonText = confirming ? 'waiting for confirmation' : 'confirm in wallet';
  const tradeButtonText = busy
    ? busyButtonText
    : tradeSide === 'buy' ? 'buy tokens' : needsCurveApproval ? 'approve curve' : 'sell tokens';
  const tradeOutput = tradeSide === 'buy' ? `${eth(maxCost)} eth max` : `${eth(minSell)} eth min`;
  const tradeInputLabel = 'token units';
  const tradeInputValue = `${tradeUnits.toString()} tokens`;
  const currentOutstanding = Number(outstanding ?? 0n);
  const publicCapNumber = Number(publicCap ?? 9975n);
  const projectedOutstanding = Math.max(0, Math.min(publicCapNumber, tradeSide === 'buy' ? currentOutstanding + Number(tradeUnits) : currentOutstanding - Number(tradeUnits)));
  const currentBandIndex = bandIndexForUnits(currentOutstanding);
  const projectedBandIndex = bandIndexForUnits(projectedOutstanding);
  const crossesBand = tradeUnits > 0n && projectedBandIndex !== currentBandIndex;
  const protectionPercent = protectionValue.toLocaleString(undefined, { maximumFractionDigits: 2 });

  useEffect(() => {
    if (!isSuccess) return;
    refetch();
    if (pendingApproval === 'curve') setCurveAllowanceOverride((current) => (current ?? 0n) > sellAmount ? current : sellAmount);
    if (pendingApproval === 'forge') setForgeAllowanceOverride((current) => (current ?? 0n) > forgeAmount ? current : forgeAmount);
    setPendingApproval(null);
  }, [isSuccess, pendingApproval, refetch, sellAmount, forgeAmount]);

  useEffect(() => {
    if (!address || !publicClient) {
      setOwnedTokenIds([]);
      setOwnedSvgs({});
      return;
    }

    let cancelled = false;
    const client = publicClient;
    const account = address.toLowerCase();
    const transferEvent = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)');

    async function loadOwnedCrystals() {
      const owners = new Map<string, string>();

      try {
        const logs = await client.getLogs({
          address: contracts.nft,
          event: transferEvent,
          fromBlock: contracts.nftStartBlock,
          toBlock: 'latest',
        });

        for (const log of logs) {
          const tokenId = log.args.tokenId?.toString();
          const to = log.args.to?.toLowerCase();
          if (!tokenId || !to) continue;
          if (to === zeroAddress) owners.delete(tokenId);
          else owners.set(tokenId, to);
        }
      } catch {
        // Some public RPCs restrict broad log queries; ownerOf scan below keeps redeem usable.
      }

      let owned = [...owners.entries()]
        .filter(([, owner]) => owner === account)
        .map(([tokenId]) => BigInt(tokenId))
        .sort((a, b) => Number(a - b));

      const expectedBalance = Number(nftBalance ?? 0n);
      const mintedCount = Number(totalMinted ?? 0n);
      if (owned.length < expectedBalance && mintedCount > 0) {
        const scanned: bigint[] = [];
        const chunkSize = 250;
        for (let start = 1; start <= mintedCount; start += chunkSize) {
          const end = Math.min(mintedCount, start + chunkSize - 1);
          const results = await client.multicall({
            allowFailure: true,
            contracts: Array.from({ length: end - start + 1 }, (_, index) => ({
              address: contracts.nft,
              abi: nftAbi,
              functionName: 'ownerOf',
              args: [BigInt(start + index)],
            })),
          });

          results.forEach((result, index) => {
            if (result.status === 'success' && String(result.result).toLowerCase() === account) {
              scanned.push(BigInt(start + index));
            }
          });
        }
        owned = scanned.sort((a, b) => Number(a - b));
      }

      const svgEntries = await Promise.all(
        owned.slice(0, 12).map(async (tokenId) => {
          const image = await client.readContract({
            address: contracts.nft,
            abi: nftAbi,
            functionName: 'imageSVG',
            args: [tokenId],
          });
          return [tokenId.toString(), image] as const;
        }),
      );

      if (!cancelled) {
        setOwnedTokenIds(owned);
        setOwnedSvgs(Object.fromEntries(svgEntries));
      }
    }

    loadOwnedCrystals().catch(() => {
      if (!cancelled) {
        setOwnedTokenIds([]);
        setOwnedSvgs({});
      }
    });

    return () => {
      cancelled = true;
    };
  }, [address, publicClient, isSuccess, nftBalance, totalMinted]);

  function ready() {
    if (!isConnected) throw new Error('connect wallet first');
    if (wrongNetwork) throw new Error('switch to the supported network');
  }

  function buy() {
    ready();
    writeContract({ address: contracts.curve, abi: curveAbi, functionName: 'buy', args: [tradeUnits, maxCost], value: maxCost });
  }

  function forgeAction() {
    ready();
    if (needsForgeApproval) {
      setPendingApproval('forge');
      writeContract({ address: contracts.b20, abi: erc20Abi, functionName: 'approve', args: [contracts.forge, forgeAmount] });
      return;
    }
    setPendingApproval(null);
    writeContract({ address: contracts.forge, abi: forgeAbi, functionName: 'forge', args: [forgeUnits] });
  }

  function redeem() {
    ready();
    writeContract({ address: contracts.forge, abi: forgeAbi, functionName: 'redeem', args: [selectedIds] });
  }

  function redeemAndSell() {
    ready();
    writeContract({ address: contracts.forge, abi: forgeAbi, functionName: 'redeemAndSell', args: [selectedIds, minRedeemSell] });
  }

  function approveCurve() {
    ready();
    setPendingApproval('curve');
    writeContract({ address: contracts.b20, abi: erc20Abi, functionName: 'approve', args: [contracts.curve, sellAmount] });
  }

  function trade() {
    ready();
    if (tradeSide === 'buy') {
      buy();
      return;
    }
    if (needsCurveApproval) {
      approveCurve();
      return;
    }
    setPendingApproval(null);
    writeContract({ address: contracts.curve, abi: curveAbi, functionName: 'sell', args: [tradeUnits, minSell] });
  }

  function toggleTokenId(tokenId: bigint) {
    const current = new Set(selectedIds.map((id) => id.toString()));
    const key = tokenId.toString();
    if (current.has(key)) current.delete(key);
    else current.add(key);
    setTokenIds([...current].join(', '));
  }

  return (
    <main className="app">
      <header className="topbar">
        <div>
          <p className="mark">beryl bits</p>
          <p className="submark">built on Base B20 standard</p>
        </div>
        <ConnectButton accountStatus="address" chainStatus="name" showBalance={false} />
      </header>

      <section className="hero">
        <div className="hero-text">
          <span className="eyebrow">1 token ↔ 1 crystal nft</span>
          <h1>buy the unit. forge the crystal. redeem when needed.</h1>
          <p>clear fees: buy pays the curve, forge and redeem stay 1:1.</p>
        </div>
        <div className="hero-stone">
          <Crystal />
        </div>
      </section>

      <section className="console">
        <aside className="mode-list" aria-label="actions">
          {modes.map((item) => (
            <button key={item} className={mode === item ? 'selected' : ''} onClick={() => setMode(item)}>
              <span>{item}</span>
              <small>{copy[item].short}</small>
            </button>
          ))}
        </aside>

        <section className="action-surface">
          <div className="action-head">
            <p>{copy[mode].kicker}</p>
            <h2>{copy[mode].title}</h2>
          </div>

          {mode === 'buy' && (
            <div className="swap-panel">
              <div className="segmented" aria-label="trade direction">
                <button className={tradeSide === 'buy' ? 'active' : ''} onClick={() => setTradeSide('buy')}>buy</button>
                <button className={tradeSide === 'sell' ? 'active' : ''} onClick={() => setTradeSide('sell')}>sell</button>
              </div>
              <div className="swap-box">
                <span>{tradeInputLabel}</span>
                <strong>{tradeInputValue}</strong>
                <input value={tradeCount} onChange={(event) => setTradeCount(event.target.value)} inputMode="numeric" aria-label="token units" />
              </div>
              <div className="swap-arrow">↓</div>
              <div className="swap-box output">
                <span>{tradeSide === 'buy' ? 'pay up to' : 'receive at least'}</span>
                <strong>{tradeOutput}</strong>
                <small>raw quote: {eth(activeTradeQuote)} eth · price protection {protectionPercent}%</small>
              </div>
              <div className="quote-strip" aria-label="trade fee summary">
                <Readout label="buy fee" value="8% to treasury" />
                <Readout label="sell payout" value="92% of band" />
                <Readout label="forge/redeem" value="0 fee" />
              </div>
              {tradeSide === 'buy' && tradeUnits > 0n ? (
                <div className="fee-breakdown" aria-label="buy cost breakdown">
                  <Readout label="you pay (quote)" value={`${eth(quoteBuy)} eth`} />
                  <Readout label="8% treasury fee" value={`${eth(buyTreasuryFee)} eth`} />
                  <Readout label="if you sell now" value={`${eth(immediateSellValue)} eth`} />
                  <Readout
                    label="round-trip spread"
                    value={roundTripLoss === undefined ? '...' : `~${(Number(roundTripLoss) / 100).toFixed(1)}% + gas`}
                  />
                </div>
              ) : null}
              {tradeSide === 'buy' && tradeUnits > 0n ? (
                <p className="fee-note">
                  An immediate buy then sell returns less than you paid. You profit only if net curve demand later moves the price into a higher band.
                </p>
              ) : null}
              {crossesBand ? (
                <div className="notice" role="status">
                  this swap crosses a curve price band. if another transaction lands first, 1% protection may revert. reduce size or use 3-5% during launch.
                </div>
              ) : null}
              {tradeSide === 'sell' ? (
                <Readout label="curve allowance" value={needsCurveApproval ? `${eth(effectiveCurveAllowance)} tokens approved` : 'ready to sell'} />
              ) : null}
              <div className="protection-row">
                <Field label="price protection %" value={priceProtection} onChange={setPriceProtection} />
                <div className="protection-presets" aria-label="price protection presets">
                  {['1', '3', '5'].map((value) => (
                    <button key={value} className={priceProtection === value ? 'active' : ''} onClick={() => setPriceProtection(value)} type="button">
                      {value}%
                    </button>
                  ))}
                </div>
              </div>
              <button className="button primary full" disabled={busy || tradeUnits === 0n || activeTradeQuote === undefined} onClick={trade}>
                {tradeButtonText}
              </button>
              <CurveGraph outstanding={outstanding} publicCap={publicCap} quoteBuy={quoteBuy} quoteSell={quoteSell} tradeUnits={tradeUnits} tradeSide={tradeSide} />
            </div>
          )}

          {mode === 'forge' && (
            <div className="action-grid">
              <Field label="crystals to forge" value={forgeCount} onChange={setForgeCount} />
              <Readout label="token balance" value={eth(b20Balance)} />
              <Readout label="forge allowance" value={eth(effectiveForgeAllowance)} />
              <Readout label="next step" value={needsForgeApproval ? 'approve token spend' : 'forge crystal nft'} />
              <button className="button primary full" disabled={busy || forgeUnits === 0n} onClick={forgeAction}>
                {busy ? busyButtonText : needsForgeApproval ? 'approve forge' : 'forge crystal'}
              </button>
            </div>
          )}

          {mode === 'redeem' && (
            <div className="action-grid">
              <Field label="selected nft ids" value={tokenIds} onChange={setTokenIds} placeholder="select below or type 5, 6" />
              <Readout label="nft balance" value={nftBalance?.toString() ?? '...'} />
              <Readout label="redeem + sell quote" value={`${eth(redeemQuote)} eth`} />
              <Readout label="selected" value={`${selectedIds.length} crystal${selectedIds.length === 1 ? '' : 's'}`} />
              <OwnedCrystals ownedTokenIds={ownedTokenIds} ownedSvgs={ownedSvgs} selectedSet={selectedSet} expectedBalance={nftBalance} connected={isConnected} onToggle={toggleTokenId} />
              <button className="button primary full" disabled={busy || selectedIds.length === 0} onClick={redeemAndSell}>{busy ? busyButtonText : 'redeem + sell selected'}</button>
              <button className="button secondary full" disabled={busy || selectedIds.length === 0} onClick={redeem}>redeem selected to tokens</button>
            </div>
          )}

          {mode === 'docs' && <DocsPanel />}

          {mode === 'system' && (
            <div className="system-grid">
              <Readout label="outstanding" value={`${outstanding?.toString() ?? '...'}/${publicCap?.toString() ?? '9975'}`} />
              <Readout label="token supply" value={eth(totalSupply)} />
              <Readout label="live nfts" value={liveSupply?.toString() ?? '...'} />
              <Readout label="total minted" value={totalMinted?.toString() ?? '...'} />
              <Readout label="team allocation" value={`${contracts.teamAllocation} tokens`} />
              <Readout
                label="team sell lock"
                value={
                  teamSellUnlockUnits === undefined
                    ? '...'
                    : teamSellUnlockUnits === 0n
                      ? 'disabled'
                      : (outstanding ?? 0n) >= teamSellUnlockUnits
                        ? `unlocked (≥ ${teamSellUnlockUnits.toString()} units)`
                        : `locked until ${teamSellUnlockUnits.toString()} units`
                }
              />
              <AddressRow label="Base B20 asset contract" address={contracts.b20} />
              <AddressRow label="curve" address={contracts.curve} />
              <AddressRow label="forge" address={contracts.forge} />
              <AddressRow label="nft" address={contracts.nft} />
              <button className="button secondary" onClick={() => refetch()}>refresh</button>
            </div>
          )}
        </section>

        <aside className="state-rail">
          <div className="preview">
            <label>
              preview token
              <input value={previewId} onChange={(event) => setPreviewId(event.target.value)} inputMode="numeric" />
            </label>
            <div className="svg-box" dangerouslySetInnerHTML={{ __html: svg ?? '<span>no live crystal</span>' }} />
          </div>
          <div className="balances">
            <Readout label="your tokens" value={eth(b20Balance)} />
            <Readout label="your nfts" value={nftBalance?.toString() ?? '...'} />
          </div>
          <p className="risk">curve price changes with net demand. crystals do not have a guaranteed eth floor.</p>
        </aside>
      </section>

      <footer className="status">
        <span aria-live="polite">{confirming ? 'waiting for confirmation' : isSuccess ? 'transaction confirmed' : wrongNetwork ? 'switch wallet to supported network' : 'ready'}</span>
        {hash ? <a href={`${explorer}/tx/${hash}`} target="_blank" rel="noreferrer">view tx</a> : null}
        {error ? <span className="error">{friendlyError(error.message)}</span> : null}
      </footer>
    </main>
  );
}

const copy = {
  buy: { short: 'eth to token', kicker: 'trade', title: 'buy or sell Beryl Bits tokens' },
  forge: { short: 'token to nft', kicker: 'forge', title: 'burn tokens and mint crystal nfts' },
  redeem: { short: 'nft to token', kicker: 'exit paths', title: 'redeem crystals or sell tokens' },
  docs: { short: 'how it works', kicker: 'docs', title: 'how Beryl Bits works' },
  system: { short: 'contracts', kicker: 'system', title: 'current public state' },
} satisfies Record<Mode, { short: string; kicker: string; title: string }>;

function friendlyError(message: string) {
  if (message.includes('User rejected') || message.includes('User denied')) return 'transaction rejected in wallet.';
  if (message.includes('insufficient funds')) return 'not enough eth for this transaction and gas.';
  if (message.includes('execution reverted')) return 'transaction reverted. check balance, allowance, price protection, or selected nft ownership.';
  if (message.includes('Connector not connected')) return 'connect wallet first.';
  return message.split('\n')[0] || 'transaction failed.';
}

function Field({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (value: string) => void; placeholder?: string }) {
  return (
    <label className="field">
      <span>{label}</span>
      <input value={value} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

function Readout({ label, value }: { label: string; value: string }) {
  return (
    <div className="readout">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function OwnedCrystals(props: {
  ownedTokenIds: bigint[];
  ownedSvgs: Record<string, string>;
  selectedSet: Set<string>;
  expectedBalance?: bigint;
  connected: boolean;
  onToggle: (tokenId: bigint) => void;
}) {
  if (props.ownedTokenIds.length === 0) {
    const message = !props.connected
      ? 'connect wallet to load your crystals.'
      : props.expectedBalance === undefined
        ? 'loading your crystals...'
        : props.expectedBalance > 0n
          ? 'scanning your crystals. you can also type token ids manually above.'
          : 'this wallet does not hold any crystals yet.';
    return <p className="empty-state">{message}</p>;
  }

  return (
    <div className="owned-grid">
      {props.ownedTokenIds.map((tokenId) => {
        const key = tokenId.toString();
        return (
          <button key={key} className={props.selectedSet.has(key) ? 'owned-token selected' : 'owned-token'} aria-pressed={props.selectedSet.has(key)} onClick={() => props.onToggle(tokenId)}>
            <span>#{key}</span>
            <div dangerouslySetInnerHTML={{ __html: props.ownedSvgs[key] ?? '<span />' }} />
          </button>
        );
      })}
    </div>
  );
}

function DocsPanel() {
  return (
    <div className="docs-panel">
      <section>
        <h3>core loop</h3>
        <p>Beryl Bits is built on the Base B20 standard. It uses one economic unit in two forms: a fungible Beryl Bits token and a crystal NFT. One token can be burned to forge one crystal NFT. One crystal NFT can be burned to mint one token back.</p>
      </section>
      <section>
        <h3>bonding curve</h3>
        <p>Users enter with ETH through the curve. Price does not rise with time; it rises only when net public demand pushes outstanding units into higher supply bands. Selling burns tokens and pays ETH from the curve reserve.</p>
      </section>
      <section>
        <h3>crystal generation</h3>
        <p>Each NFT is generated fully onchain as SVG. The art is a centered pixel beryl crystal with deterministic traits for color, cut, facets, inclusions, clarity, and background.</p>
      </section>
      <section>
        <h3>fees and risk</h3>
        <p>Buy trades send 8% to treasury. Sell payout is 92% of the active band price, so an immediate buy/sell round trip has about a 16% spread before gas. Forge and redeem have no protocol fee. There is no guaranteed ETH floor for NFTs.</p>
      </section>
      <section>
        <h3>team allocation and sell lock</h3>
        <p>The team holds a small fixed allocation of direct-minted tokens. To keep this transparent, the curve enforces an on-chain team sell lock: the team wallet cannot pull ETH out of the curve until public demand reaches a published threshold, so ETH backing exists before any team exit. The current lock status is shown in the System tab.</p>
      </section>
    </div>
  );
}

function CurveGraph(props: { outstanding?: bigint; publicCap?: bigint; quoteBuy?: bigint; quoteSell?: bigint; tradeUnits: bigint; tradeSide: TradeSide }) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [hoverUnits, setHoverUnits] = useState<number | null>(null);

  const maxUnits = Number(props.publicCap ?? 9975n);
  const current = Number(props.outstanding ?? 0n);
  const tradeDelta = Number(props.tradeUnits);
  const projected = Math.max(0, Math.min(maxUnits, props.tradeSide === 'buy' ? current + tradeDelta : current - tradeDelta));
  const activeBand = curveBands[bandIndexForUnits(current)];
  const progress = Math.min(100, (current / maxUnits) * 100);
  const projectedProgress = Math.min(100, (projected / maxUnits) * 100);
  const hasSwap = tradeDelta > 0 && projected !== current;

  const VB = { w: 900, h: 320 };
  const frame = { left: 70, top: 26, width: 800, height: 232 };
  const chartBottom = frame.top + frame.height;
  const chartRight = frame.left + frame.width;
  const maxPrice = 0.0034;
  const x = (u: number) => frame.left + (u / maxUnits) * frame.width;
  const y = (p: number) => frame.top + frame.height - (p / maxPrice) * frame.height;

  // True step function: price is flat within a band and jumps at band edges.
  const stepPts: Array<{ x: number; y: number }> = [];
  curveBands.forEach((band, i) => {
    const start = i === 0 ? 0 : curveBands[i - 1].end;
    stepPts.push({ x: x(start), y: y(band.price) });
    stepPts.push({ x: x(band.end), y: y(band.price) });
  });
  const stepLine = stepPts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ');
  const stepArea = `${stepLine} L ${chartRight.toFixed(1)} ${chartBottom} L ${frame.left} ${chartBottom} Z`;

  const priceAt = (u: number) => curveBands[bandIndexForUnits(u)].price;
  const activeStart = (() => {
    const i = bandIndexForUnits(current);
    return i === 0 ? 0 : curveBands[i - 1].end;
  })();
  const activeEnd = curveBands[bandIndexForUnits(current)].end;

  function onMove(e: ReactMouseEvent<SVGSVGElement>) {
    const svg = svgRef.current;
    if (!svg) return;
    const rect = svg.getBoundingClientRect();
    const vx = ((e.clientX - rect.left) / rect.width) * VB.w;
    const u = Math.round(Math.max(0, Math.min(maxUnits, ((vx - frame.left) / frame.width) * maxUnits)));
    setHoverUnits(u);
  }

  const hoverPrice = hoverUnits === null ? null : priceAt(hoverUnits);
  const hoverX = hoverUnits === null ? 0 : x(hoverUnits);
  const tipW = 148;
  const tipX = Math.min(Math.max(hoverX - tipW / 2, frame.left), chartRight - tipW);

  return (
    <div className="curve-card">
      <div className="curve-head">
        <div>
          <span>bonding curve</span>
          <strong>true step pricing</strong>
        </div>
        <strong>{current.toLocaleString()} / {maxUnits.toLocaleString()} units</strong>
      </div>

      <svg
        ref={svgRef}
        viewBox={`0 0 ${VB.w} ${VB.h}`}
        role="img"
        className="curve-svg"
        aria-label={`bonding curve. current ${current} units at ${bandPrice(activeBand.price)} eth. hover to inspect price at any demand level.`}
        onMouseMove={onMove}
        onMouseLeave={() => setHoverUnits(null)}
      >
        <defs>
          <linearGradient id="curveFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#0052ff" stopOpacity="0.20" />
            <stop offset="100%" stopColor="#0052ff" stopOpacity="0.01" />
          </linearGradient>
        </defs>

        {curveBands.map((band) => (
          <g key={`y-${band.price}`}>
            <line className="curve-grid" x1={frame.left} x2={chartRight} y1={y(band.price)} y2={y(band.price)} />
            <text className="curve-y-label" x={frame.left - 10} y={y(band.price) + 4} textAnchor="end">{bandPrice(band.price)}</text>
          </g>
        ))}

        <rect className="curve-band active" x={x(activeStart)} y={frame.top} width={x(activeEnd) - x(activeStart)} height={frame.height} />

        <path className="curve-step-area" d={stepArea} />
        <path className="curve-step-line" d={stepLine} />

        {hasSwap ? (
          <>
            <line className="curve-projected-line" x1={x(projected)} x2={x(projected)} y1={frame.top} y2={chartBottom} />
            <circle className="curve-projected-dot" cx={x(projected)} cy={y(priceAt(projected))} r="5" />
            <text
              className="curve-projected-label"
              x={Math.min(Math.max(x(projected), frame.left + 28), chartRight - 28)}
              y={y(priceAt(projected)) - 12}
              textAnchor="middle"
            >
              {props.tradeSide === 'buy' ? 'buy' : 'sell'} → {bandPrice(priceAt(projected))} eth
            </text>
          </>
        ) : null}

        <line className="curve-current-line" x1={x(current)} x2={x(current)} y1={frame.top - 6} y2={chartBottom} />
        <circle className="curve-current-dot" cx={x(current)} cy={y(activeBand.price)} r="5" />
        <text className="curve-now-label" x={Math.min(x(current) + 8, chartRight - 30)} y={frame.top + 2}>now</text>

        {hoverUnits !== null && hoverPrice !== null ? (
          <g pointerEvents="none">
            <line className="curve-hover-line" x1={hoverX} x2={hoverX} y1={frame.top} y2={chartBottom} />
            <circle className="curve-hover-dot" cx={hoverX} cy={y(hoverPrice)} r="4" />
            <g transform={`translate(${tipX.toFixed(1)}, ${frame.top + 6})`}>
              <rect className="curve-tip-box" width={tipW} height="58" rx="8" />
              <text className="curve-tip-title" x="12" y="21">{hoverUnits.toLocaleString()} units sold</text>
              <text className="curve-tip-row" x="12" y="39">buy {bandPrice(hoverPrice)} eth</text>
              <text className="curve-tip-row" x="12" y="52">sell {bandPrice(hoverPrice * 0.92)} eth</text>
            </g>
          </g>
        ) : null}

        <text className="curve-axis-title" x={frame.left} y={frame.top - 12}>price / token (eth)</text>
        <text className="curve-axis-title" x={chartRight} y={chartBottom + 26} textAnchor="end">units sold →</text>
      </svg>

      <div className="curve-meter" role="progressbar" aria-valuenow={Math.round(projectedProgress)} aria-valuemin={0} aria-valuemax={100}>
        <i className="meter-current" style={{ width: `${Math.min(progress, projectedProgress)}%` }} />
        {hasSwap ? (
          <i
            className={`meter-projected ${props.tradeSide}`}
            style={{ left: `${Math.min(progress, projectedProgress)}%`, width: `${Math.abs(projectedProgress - progress)}%` }}
          />
        ) : null}
      </div>
      <div className="curve-stats">
        <Readout label={hasSwap ? 'after swap' : 'progress'} value={`${(hasSwap ? projectedProgress : progress).toFixed(1)}%`} />
        <Readout label="buy quote" value={`${eth(props.quoteBuy)} eth`} />
        <Readout label="sell quote" value={`${eth(props.quoteSell)} eth`} />
      </div>
      <p className="curve-note">Price is a true step function — it changes only when net demand crosses a band edge. Hover the chart to inspect any level.</p>
    </div>
  );
}

function AddressRow({ label, address }: { label: string; address: Address }) {
  return (
    <a className="address-row" href={`${explorer}/address/${address}`} target="_blank" rel="noreferrer">
      <span>{label}</span>
      <code>{address}</code>
    </a>
  );
}

function Crystal() {
  return (
    <img className="hero-crystal-image" src="/beryl-crystal.svg" alt="pixel beryl crystal" />
  );
}
