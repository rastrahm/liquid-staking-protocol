# Flujograma — Ciclo completo Liquid Staking Protocol

Flujo extremo a extremo entre stakers, pool, oracle, deposit contract y withdrawal queue (módulo 18, **v1 — diseño**).  
**Sync:** 2026-09-14.

## Actores

| Actor | Rol |
|-------|-----|
| Staker | Deposita ETH (`submit`); opcionalmente wrap a `wstETH`; solicita unstake |
| Node Operator | Aporta signing keys; recibe fee de rewards |
| Oracle Committee | Firma/reporta balances CL + rewards EL; dispara rebase |
| LiquidStakingPool / StETH | Contabilidad shares, buffer, total pooled ether |
| WstETH | Wrapper no-rebasing para DeFi / composabilidad |
| WithdrawalQueue | Cola asíncrona request → finalize → claim |
| Eth2 Deposit Contract | Recibe depósitos de 32 ETH por validador |
| FeeDistributor / Treasury | Split de fees con cap inmutable |
| Keeper | Llama `depositBufferedEther` cuando buffer ≥ 32 ETH |
| CI / Foundry | Unit, fuzz rebase+/−, lifecycle withdrawal, gas |

---

## Flujograma — Deploy

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy: StETH/Pool + WstETH + WithdrawalQueue + Oracle + FeeDistributor + NodeOps]
    Dep --> Wire[Wire: oracle, depositContract, queue, fee recipients]
    Wire --> Caps[Set MAX_PROTOCOL_FEE_BPS inmutable / immutable caps]
    Caps --> Ready([Protocolo listo — sin validadores aún])
```

---

## Flujograma principal — Stake → Accrue → Unstake

```mermaid
flowchart TD
    Start([Staker envía ETH]) --> Sub[submit → mint shares / stETH]
    Sub --> Buf[ETH en bufferedEther]
    Buf --> Opt{¿wrap a wstETH?}
    Opt -->|Sí| W[wrap: lock stETH → mint wstETH]
    Opt -->|No| Hold[Hold stETH rebasing]
    W --> Hold2[Hold wstETH value-accruing]
    Buf --> Keep[Keeper: depositBufferedEther]
    Keep --> DC[Eth2 DepositContract 32 ETH × N]
    DC --> Val[Validadores activos en beacon]
    Val --> Or[Oracle report CL balance + EL rewards]
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
    Queue --> Fin[finalize por oracle/pool]
    Fin --> Claim[claimWithdrawal → ETH]
    Claim --> Done([Staker recibe ETH])
```

---

## Flujograma — Capas de defensa (oracle + withdraw)

```mermaid
flowchart TD
    A[Acción sensible] --> B{¿Oracle report?}
    B -->|Sí| C1[1. Firmas / membership comité]
    C1 --> C2[2. Intervalo / refSlot]
    C2 --> C3[3. Consistencia balances]
    C3 --> C4[4. Fee <= cap inmutable]
    C4 --> C5[5. Negative rebase sin romper solvencia]
    C5 --> Ok1([handleOracleReport OK])
    C1 -.->|fail| X1[UnauthorizedOracle]
    C2 -.->|fail| X2[ReportTooEarly / InvalidReport]
    C4 -.->|fail| X3[FeeCapExceeded]
    C5 -.->|fail| X4[NegativeRebaseBlocked]

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
    Start([ETH in / out o rebase]) --> TPE[totalPooledEther]
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
    A[forge build] --> B[Unit: submit mint ratio]
    B --> C[Unit: positive rebase]
    C --> D[Unit: negative rebase / slash]
    D --> E[Unit: wrap / unwrap parity]
    E --> F[Unit: withdrawal lifecycle]
    F --> G[Fuzz: slashing resilience]
    G --> H[Gas snapshot]
    H --> I[forge test verde]
```

---

## Relación con otros docs

| Documento | Contenido |
|-----------|-----------|
| [diagrama-de-clases.md](./diagrama-de-clases.md) | Contratos, interfaces, librerías |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones internas por función |
| [planificacion.md](./planificacion.md) | Fases con gate de autorización |
