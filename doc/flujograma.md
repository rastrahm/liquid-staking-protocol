# Flujograma — Ciclo completo Liquid Staking Protocol

Flujo extremo a extremo entre stakers, pool, oracle, deposit contract y withdrawal queue (módulo 18, **v1 implementado**).  
**Sync:** 2026-09-14 · Fases **0–7** ✅ · 90 PASS.

## Actores

| Actor | Rol |
|-------|-----|
| Staker | Deposita ETH (`submit`); opcionalmente wrap a `wstETH`; solicita unstake |
| Node Operator | Aporta signing keys; recibe fee de rewards |
| Oracle Committee | Miembros on-chain llaman `submitReport` (CL + EL); dispara rebase |
| StETH (pool) | Contabilidad shares, buffer, CL, deposits, finalizeWithdrawals |
| WstETH | Wrapper no-rebasing para DeFi / composabilidad |
| WithdrawalQueue | Cola asíncrona request → finalize → claim |
| Eth2 Deposit Contract | Recibe depósitos de 32 ETH por validador (mock en lab) |
| FeeDistributor / Treasury | Split de fees con cap inmutable 10% |
| Keeper | Llama `depositBufferedEther` cuando buffer ≥ 32 ETH |
| CI / Foundry | Unit, fuzz rebase+/−, lifecycle withdrawal, invariantes, gas |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy: StETH + WstETH + WithdrawalQueue + Oracle + FeeDistributor + NodeOps + MockDeposit]
    Dep --> Wire[Wire: setOracle, setFeeDistributor, setDepositContract, setOperatorsRegistry, setWithdrawalQueue, setFinalizer]
    Wire --> Caps[FeeDistributor: MAX_PROTOCOL_FEE_BPS=1000 inmutable]
    Caps --> Ready([Protocolo listo — sin validadores aún])
```

> Deploy lab: `queue.setFinalizer(address(oracle))`. Pueden finalizar `owner` o `finalizer`.

---

## Flujograma principal — Stake → Accrue → Unstake

```mermaid
flowchart TD
    Start([Staker envía ETH]) --> Sub[submit → mint shares / stETH]
    Sub --> Buf[ETH en bufferedEther]
    Buf --> Opt{¿wrap a wstETH?}
    Opt -->|Sí| W[wrap: lock stETH → mint wstETH = shares]
    Opt -->|No| Hold[Hold stETH rebasing]
    W --> Hold2[Hold wstETH value-accruing]
    Buf --> Keep[Keeper: depositBufferedEther]
    Keep --> DC[Eth2 DepositContract 32 ETH × N]
    DC --> Val[Validadores activos en beacon]
    Val --> Or[Oracle submitReport → handleOracleReport]
    Or --> Rebase{¿rewards o slash?}
    Rebase -->|Positive| Pos[Fee split + rate ↑ → stETH balance ↑]
    Rebase -->|Negative| Neg[rate ↓ → stETH balance ↓; solvencia OK]
    Pos --> Accrue[wstETH: stEthPerToken ↑]
    Neg --> Accrue2[wstETH: stEthPerToken ↓]
    Hold --> Unstake
    Hold2 --> Unwrap[unwrap → stETH] --> Unstake
    Accrue --> Unstake
    Accrue2 --> Unstake
    Unstake[requestWithdrawals] --> Queue[Cola: shares locked]
    Queue --> Fin[finalize → StETH.finalizeWithdrawals]
    Fin --> Claim[claimWithdrawal → ETH]
    Claim --> Done([Staker recibe ETH])
```

---

## Flujograma — Capas de defensa (oracle + withdraw)

```mermaid
flowchart TD
    A[Acción sensible] --> B{¿Oracle report?}
    B -->|Sí| C1[1. Membership comité on-chain]
    C1 --> C2[2. Intervalo reportInterval]
    C2 --> C3[3. msg.sender == StETH.oracle]
    C3 --> C4[4. Consistencia EL rewards vs balance]
    C4 --> C5[5. Fee cap en constructor FeeDistributor]
    C5 --> C6[6. Negative rebase: no pooled=0 con shares>0]
    C6 --> Ok1([handleOracleReport OK])
    C1 -.->|fail| X1[UnauthorizedOracle]
    C2 -.->|fail| X2[ReportTooEarly]
    C3 -.->|fail| X1
    C4 -.->|fail| X3[InvalidReport]
    C6 -.->|fail| X4[NegativeRebaseBlocked]

    B -->|No — claim| D1[1. request finalized]
    D1 --> D2[2. no claimed aún]
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

## Flujograma — Contabilidad shares (WAD / RAY)

```mermaid
flowchart TD
    Start([ETH in / out o rebase]) --> TPE[totalPooledEther = buffer + clBalance]
    Start --> TS[totalShares]
    TPE --> Rate[shareRate = pooledEth / shares]
    TS --> Rate
    Rate --> Bal[stETH.balanceOf = sharesOf * rate]
    Rate --> WRate[wstETH.stEthPerToken = rate]
    Bal --> User[Usuario ve rebase automático]
    WRate --> Defi[Integraciones DeFi usan balance fijo]
```

---

## Flujograma — Tooling Foundry (lab)

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

## Relación con otros docs

| Documento | Contenido |
|-----------|-----------|
| [diagrama-de-clases.md](./diagrama-de-clases.md) | Contratos, interfaces, librerías (implementación) |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones internas por función |
| [planificacion.md](./planificacion.md) | Fases 0–7 cerradas, arquitectura v1 |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC |
| [GAS.md](./GAS.md) | Baseline gas |
