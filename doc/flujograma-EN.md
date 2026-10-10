# Flowchart — Full Liquid Staking Protocol cycle

**Language:** English · [Español](./flujograma-ES.md)

End-to-end flow between stakers, pool, oracle, deposit contract, and withdrawal queue (module 18, **v1 implemented**).  
**Sync:** 2026-09-14 · Phases **0–7** ✅ · 90 PASS.

## Actors

| Actor | Role |
|-------|------|
| Staker | Deposits ETH (`submit`); optionally wraps into `wstETH`; requests unstake |
| Node Operator | Provides signing keys; receives a share of reward fees |
| Oracle Committee | On-chain members call `submitReport` (CL + EL); triggers rebase |
| StETH (pool) | Shares accounting, buffer, CL, deposits, finalizeWithdrawals |
| WstETH | Non-rebasing wrapper for DeFi / composability |
| WithdrawalQueue | Asynchronous queue request → finalize → claim |
| Eth2 Deposit Contract | Receives 32 ETH deposits per validator (mock in lab) |
| FeeDistributor / Treasury | Fee split with immutable 10% cap |
| Keeper | Calls `depositBufferedEther` when buffer ≥ 32 ETH |
| CI / Foundry | Unit, +/− rebase fuzz, withdrawal lifecycle, invariants, gas |

---

## Flowchart — Deploy

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy: StETH + WstETH + WithdrawalQueue + Oracle + FeeDistributor + NodeOps + MockDeposit]
    Dep --> Wire[Wire: setOracle, setFeeDistributor, setDepositContract, setOperatorsRegistry, setWithdrawalQueue, setFinalizer]
    Wire --> Caps[FeeDistributor: MAX_PROTOCOL_FEE_BPS=1000 immutable]
    Caps --> Ready([Protocol ready — no validators yet])
```

> Lab deploy: `queue.setFinalizer(address(oracle))`. Either `owner` or `finalizer` can finalize.

---

## Main flowchart — Stake → Accrue → Unstake

```mermaid
flowchart TD
    Start([Staker sends ETH]) --> Sub[submit → mint shares / stETH]
    Sub --> Buf[ETH in bufferedEther]
    Buf --> Opt{Wrap into wstETH?}
    Opt -->|Yes| W[wrap: lock stETH → mint wstETH = shares]
    Opt -->|No| Hold[Hold rebasing stETH]
    W --> Hold2[Hold value-accruing wstETH]
    Buf --> Keep[Keeper: depositBufferedEther]
    Keep --> DC[Eth2 DepositContract 32 ETH × N]
    DC --> Val[Active validators on beacon chain]
    Val --> Or[Oracle submitReport → handleOracleReport]
    Or --> Rebase{Rewards or slash?}
    Rebase -->|Positive| Pos[Fee split + rate ↑ → stETH balance ↑]
    Rebase -->|Negative| Neg[rate ↓ → stETH balance ↓; solvency OK]
    Pos --> Accrue[wstETH: stEthPerToken ↑]
    Neg --> Accrue2[wstETH: stEthPerToken ↓]
    Hold --> Unstake
    Hold2 --> Unwrap[unwrap → stETH] --> Unstake
    Accrue --> Unstake
    Accrue2 --> Unstake
    Unstake[requestWithdrawals] --> Queue[Queue: shares locked]
    Queue --> Fin[finalize → StETH.finalizeWithdrawals]
    Fin --> Claim[claimWithdrawal → ETH]
    Claim --> Done([Staker receives ETH])
```

---

## Flowchart — Defense layers (oracle + withdraw)

```mermaid
flowchart TD
    A[Sensitive action] --> B{Oracle report?}
    B -->|Yes| C1[1. On-chain committee membership]
    C1 --> C2[2. reportInterval]
    C2 --> C3[3. msg.sender == StETH.oracle]
    C3 --> C4[4. EL rewards vs balance consistency]
    C4 --> C5[5. Fee cap in FeeDistributor constructor]
    C5 --> C6[6. Negative rebase: no pooled=0 with shares>0]
    C6 --> Ok1([handleOracleReport OK])
    C1 -.->|fail| X1[UnauthorizedOracle]
    C2 -.->|fail| X2[ReportTooEarly]
    C3 -.->|fail| X1
    C4 -.->|fail| X3[InvalidReport]
    C6 -.->|fail| X4[NegativeRebaseBlocked]

    B -->|No — claim| D1[1. request finalized]
    D1 --> D2[2. not claimed yet]
    D2 --> D3[3. caller = owner]
    D3 --> D4[4. CEI: claimed=true]
    D4 --> D5[5. call value ETH]
    D5 --> Ok2([Claim OK])
    D1 -.->|fail| Y1[WithdrawalNotFinalized]
    D2 -.->|fail| Y2[WithdrawalAlreadyClaimed]
    D3 -.->|fail| Y3[WithdrawalNotOwner]
    D5 -.->|fail| Y4[EthTransferFailed]
```

---

## Flowchart — Shares accounting (WAD / RAY)

```mermaid
flowchart TD
    Start([ETH in / out or rebase]) --> TPE[totalPooledEther = buffer + clBalance]
    Start --> TS[totalShares]
    TPE --> Rate[shareRate = pooledEth / shares]
    TS --> Rate
    Rate --> Bal[stETH.balanceOf = sharesOf * rate]
    Rate --> WRate[wstETH.stEthPerToken = rate]
    Bal --> User[User sees automatic rebase]
    WRate --> Defi[DeFi integrations use a fixed balance]
```

---

## Flowchart — Foundry tooling (lab)

```mermaid
flowchart TD
    A[forge build] --> B[Unit: ShareMath / StETH / WstETH]
    B --> C[Unit: OracleReport +/− rebase]
    C --> D[Unit: DepositBufferedEther]
    D --> E[Unit: WithdrawalQueue lifecycle]
    E --> F[Fuzz: SlashingResilience]
    F --> G[Invariant: PoolSolvency]
    G --> H[Gas snapshot LiquidStakingGasTest]
    H --> I[forge test → 90 PASS]
```

---

## Related docs

| Document | Content |
|----------|---------|
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | Contracts, interfaces, libraries (implementation) |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Internal per-function decisions |
| [planificacion-EN.md](./planificacion-EN.md) | Phases 0–7 closed, v1 architecture |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC matrix |
| [GAS-EN.md](./GAS-EN.md) | Gas baseline |
