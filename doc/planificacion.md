# Planificación — Módulo 18: Liquid Staking & Staking Derivatives

**Estado:** Fases **0–4** ✅ · Fases **5–7** 🔒 pendientes.  
**Regla de avance:** cada fase requiere **autorización explícita** del responsable antes de empezar (*“autorizo Fase N”* o equivalente).
**Suite:** `forge test` → **66 PASS**.

---

## 1. Objetivo

Construir un protocolo de **liquid staking** estilo stETH/wstETH que permita:

- Depositar ETH y recibir un token **rebasing** (`stETH`) basado en **shares**.
- Envolver `stETH` en un wrapper **value-accruing** (`wstETH`) para composabilidad DeFi.
- Integrar el **Eth2 Deposit Contract** (spec `0x00000000219ab540356cBB839Cbe05303d7705Fa`) para activar validadores de 32 ETH.
- Distribuir rewards vía **oracle** autorizado (balances CL + rewards EL) con rebase positivo y **negative rebase** (slashing) sin romper solvencia.
- Procesar unstake mediante **WithdrawalQueue** asíncrona (`requestId`-backed).
- Aplicar **fee split** con caps inmutables entre stakers, treasury y node operators.
- Usar precisión **WAD (1e18) / RAY (1e27)** en conversiones shares ↔ ETH.

Stack: **Foundry + Solidity `0.8.24`**. Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `StETH` shares-based rebasing ERC-20 | Multi-chain / L2 nativo |
| `WstETH` wrap/unwrap value-accruing | stETH en restaking (EigenLayer, etc.) |
| `LiquidStakingPool` buffer + deposit 32 ETH | Distributed Validator Technology (DVT) |
| `AccountingOracle` comité + `UnauthorizedOracle()` | Oracle descentralizado Chainlink-only |
| `WithdrawalQueue` request-ID (no NFT obligatorio) | NFT withdrawal tickets (post-v1 opcional) |
| `FeeDistributor` caps inmutables CL/EL | Governance on-chain de fees |
| `ShareMath` WAD/RAY | Vaults / strategies encima del LST |
| `NodeOperatorsRegistry` keys básicas | Marketplace de operadores |
| Tests: mint ratio, rebase +/−, queue lifecycle, fuzz slash | Frontend Next.js (App Router) |
| `Deploy.s.sol` + mocks DepositContract | Mainnet production hardening / insurance |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step` / `AccessControl` donde aplique).
- Foundry: unit + fuzz (`runs >= 1000`) + invariant + gas reports / snapshot.
- **Custom errors** (no `require` strings).
- CEI estricto; ETH vía **`.call{value: ...}("")`** (nunca `transfer`/`send`).
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests primero en fases de contratos.

### Módulo 18 (`.cursorrules` local)

- Dual-token: `stETH` (rebasing shares) + `wstETH` (wrapper).
- Oracle restringido → `error UnauthorizedOracle()`.
- Negative rebase (slashing) sin bloquear fondos ni overflow en converter.
- `WithdrawalQueue` asíncrona post-finality.
- Fee caps inmutables: operadores / treasury / stakers.
- Math: Ray/Wad (`1e27` / `1e18`).
- Deposit Contract interface Eth2 standard.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI stake / wrap / request-withdraw / claim: App Router, Zod, Vitest + RTL, JSDoc, sin `any`.
- Fuera de fases 0–7.

---

## 4. Arquitectura (propuesta v1)

```
18-liquid-staking-protocol/
├── README.md
├── .cursorrules
├── .gitignore
├── doc/
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   └── flujograma.md
├── src/
│   ├── LiquidStakingPool.sol       # Core: buffer, report, deposits
│   ├── StETH.sol                   # Rebasing ERC-20 (o unificado con pool)
│   ├── WstETH.sol                  # Wrapper value-accruing
│   ├── AccountingOracle.sol        # Comité + reportes
│   ├── WithdrawalQueue.sol         # request → finalize → claim
│   ├── FeeDistributor.sol          # Split + caps
│   ├── NodeOperatorsRegistry.sol   # Signing keys
│   ├── interfaces/
│   │   ├── ILiquidStakingPool.sol
│   │   ├── IStETH.sol
│   │   ├── IWstETH.sol
│   │   ├── IWithdrawalQueue.sol
│   │   ├── IAccountingOracle.sol
│   │   └── IDepositContract.sol
│   ├── libraries/
│   │   └── ShareMath.sol           # WAD / RAY conversions
│   ├── errors/
│   │   └── LiquidStakingErrors.sol
│   └── mocks/
│       ├── MockDepositContract.sol
│       └── MockOracle.sol
├── test/
│   ├── ShareMath.t.sol
│   ├── StETH.t.sol
│   ├── WstETH.t.sol
│   ├── LiquidStakingPool.t.sol
│   ├── OracleReport.t.sol
│   ├── WithdrawalQueue.t.sol
│   ├── FeeDistributor.t.sol
│   ├── fuzz/
│   │   └── SlashingResilience.t.sol
│   ├── invariant/
│   │   └── PoolSolvency.t.sol
│   └── gas/
│       └── LiquidStaking.gas.t.sol
├── script/
│   └── Deploy.s.sol
├── foundry.toml
├── remappings.txt
├── .env.example
└── .gas-snapshot
```

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `StETH` / Pool | Submit ETH → mint shares; `balanceOf` rebasing |
| `WstETH` | Wrap/unwrap; rate `stEthPerToken` |
| `AccountingOracle` | Solo comité; llama `handleOracleReport` |
| `WithdrawalQueue` | Lock shares; finalize; claim ETH |
| `FeeDistributor` | Mint fee shares a treasury/operators |
| `ShareMath` | `ethToShares` / `sharesToEth` WAD-safe |
| `NodeOperatorsRegistry` | Keys para `depositBufferedEther` |
| `IDepositContract` | Interfaz Eth2 + mock en tests |

---

## 5. Errores custom (módulo)

```solidity
error UnauthorizedOracle();        // obligatorio (.cursorrules)
error ZeroDeposit();
error InsufficientBalance();
error InvalidReport();
error ReportTooEarly();
error NegativeRebaseBlocked();     // opcional: clamp vs revert según diseño Fase 3
error WithdrawalNotFinalized();
error WithdrawalAlreadyClaimed();
error WithdrawalNotOwner();
error FeeCapExceeded();
error EthTransferFailed();
error ZeroAddress();
error Paused();
error NoSigningKeys();
error MathDivisionByZero();        // ShareMath.mulDiv
```

Obligatorios del módulo: `UnauthorizedOracle()`, dual-token accounting, withdrawal queue lifecycle, fee caps, manejo de negative rebase.

### Parámetros iniciales (v1 lab)

| Parámetro | Valor propuesto v1 |
|-----------|-------------------|
| `MAX_PROTOCOL_FEE_BPS` | `1000` (10%) inmutable |
| Precisión | WAD `1e18`, RAY `1e27` donde aplique rate |
| Deposit size | `32 ether` por validador |
| Oracle `REPORT_INTERVAL` | configurable (p.ej. 1 hours en tests) |
| Withdrawal mode | `requestId` (uint256), no NFT en v1 |

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + errors/math stub | ✅ Completada | ✅ Autorizada |
| 1 | `ShareMath` + `StETH` submit/mint shares | ✅ Completada | ✅ Autorizada |
| 2 | `WstETH` wrap/unwrap | ✅ Completada | ✅ Autorizada |
| 3 | `AccountingOracle` + rebase +/− + fees | ✅ Completada | ✅ Autorizada |
| 4 | `NodeOperatorsRegistry` + DepositContract integration | ✅ Completada | ✅ Autorizada |
| 5 | `WithdrawalQueue` request / finalize / claim | 🔒 Pendiente | — |
| 6 | Suite seguridad: fuzz slash + invariantes solvencia | 🔒 Pendiente | — |
| 7 | Gas + Deploy + NatSpec / cierre v1 | 🔒 Pendiente | — |

**Cómo autorizar:** responde en el chat con `Autorizo Fase N` (o rechaza con cambios concretos).

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry + estructura ✅

**Objetivo:** repo compilable con layout del módulo y stubs.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencias: `forge-std`, OpenZeppelin v5.
3. Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{fuzz,invariant,gas}`, `script/`.
4. `LiquidStakingErrors.sol` + stub `ShareMath` + `Placeholder` smoke test.
5. `.env.example`, `README.md`, `remappings.txt`.

**Criterio de salida:** `forge build` y `forge test` en verde (smoke).

**Hecho (2026-09-14):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored): forge-std **v1.16.2**, OpenZeppelin **v5.2.0** (copiadas del módulo 16).
- Carpetas `src/{interfaces,libraries,errors,mocks}`, `test/{fuzz,invariant,gas,helpers}`, `script/`.
- `src/errors/LiquidStakingErrors.sol` — 15 custom errors (incl. `UnauthorizedOracle`, `MathDivisionByZero`).
- `src/libraries/ShareMath.sol` — WAD/RAY + stubs `ethToShares` / `sharesToEth` / `mulDiv`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping, remapping IERC20, ShareMath, selector oracle, fuzz).
- Stub `script/Deploy.s.sol` (Fase 7); `.env.example`; `README.md`.
- `forge build` OK; `forge test` → **8 PASS** (fuzz 1000).

---

### Fase 1 — ShareMath + StETH submit ✅

**Objetivo:** depósito ETH → mint shares con ratio correcto bajo distintos `totalPooledEther`.

1. TDD: `ethToShares` / `sharesToEth`; primer depósito; deposits posteriores con rate ≠ 1.
2. `StETH` / pool mínimo: `submit`, `sharesOf`, `balanceOf` rebasing, `getTotalPooledEther`.
3. Eventos `Submitted` / `Transfer`; custom errors.
4. CEI + reentrancy guard en submit.

**Criterio de salida:** unit + fuzz de ratios deposit-to-share en verde.

**Hecho (2026-09-14):**
- `ShareMath`: WAD/RAY, `ethToShares` / `sharesToEth` / `mulDiv` / `shareRateRay` vía OZ `Math.mulDiv` (512-bit).
- `IStETH` + `StETH`: `submit` / `receive`, shares rebasing, ERC-20 (`transfer`/`approve`/`transferFrom`), `transferShares`.
- Contabilidad: `bufferedEther + clBalance`; `ReentrancyGuardTransient`; CEI en `_submit`.
- Harnesses de test: `ShareMathHarness`, `StETHHarness` (`simulateRewards` / `simulateLoss`).
- Tests: `ShareMath.t.sol`, `StETH.t.sol` (primer depósito 1:1, rebase +/−, fuzz ratios).
- Eliminado stub `Placeholder`.
- **`forge test` → 29 PASS**.

---

### Fase 2 — WstETH wrapper ✅

**Objetivo:** wrap/unwrap con paridad de valor y balance ERC-20 no rebasing.

1. TDD: wrap N stETH → unwrap recupera ≈ N (tolerancia dust); tras rebase simulado, `stEthPerToken` cambia y `balanceOf(wstETH)` no.
2. Approve/transfer stETH al wrapper; mint/burn wstETH.
3. Views: `getWstETHByStETH`, `getStETHByWstETH`, `stEthPerToken`, `tokensPerStEth`.

**Criterio de salida:** tests de paridad wrap/unwrap + post-rebase en verde.

**Hecho (2026-09-14):**
- `IWstETH` + `WstETH` (OZ `ERC20` + `ReentrancyGuardTransient`).
- `wrap` / `unwrap`; `receive()` ETH → `stETH.submit` + mint wstETH.
- Views de rate; 1 wstETH = 1 share; balance no rebasea tras rewards.
- Tests: `WstETH.t.sol` (paridad, post-rebase, fuzz).
- **`forge test` → 44 PASS**.

---

### Fase 3 — Oracle + rebase + fees ✅

**Objetivo:** reportes autorizados actualizan pooled ether; fees con cap; negative rebase seguro.

1. TDD: `UnauthorizedOracle` revert; positive rebase aumenta `balanceOf` holders; negative rebase lo reduce sin underflow/lock.
2. `AccountingOracle` + `handleOracleReport` en pool.
3. `FeeDistributor`: mint shares de fee; `FeeCapExceeded`.
4. Intervalo mínimo entre reportes.

**Criterio de salida:** tests positive/negative rebase + auth oracle en verde.

**Hecho (2026-09-14):**
- `FeeDistributor`: `MAX_PROTOCOL_FEE_BPS=1000`, split treasury/operators inmutable.
- `AccountingOracle`: comité, `submitReport`, intervalo, `UnauthorizedOracle` / `ReportTooEarly`.
- `StETH.handleOracleReport`: CL + EL rewards, fee mint Lido-style, `NegativeRebaseBlocked` si pooled=0 con shares.
- `Ownable2Step` + `setOracle` / `setFeeDistributor`.
- Tests: `OracleReport.t.sol`.
- **`forge test` → 57 PASS**.

---

### Fase 4 — Validators + Deposit Contract ✅

**Objetivo:** drenar buffer en múltiplos de 32 ETH hacia el deposit contract.

1. Mock `IDepositContract` + `NodeOperatorsRegistry` (keys).
2. `depositBufferedEther(maxDeposits)`.
3. Contadores `depositedValidators` / tracking beacon balance inicial post-deposit.

**Criterio de salida:** tests de depósito 32 ETH × N y fallo sin keys/buffer.

**Hecho (2026-09-14):**
- `IDepositContract` + `MockDepositContract` (lab Eth2 deposit).
- `NodeOperatorsRegistry`: operadores, signing keys 48/96, `assignNextSigningKeys` solo pool.
- `StETH.depositBufferedEther`: buffer → deposit contract; `clBalance` provisional; pooled invariante.
- `depositedValidators`, `withdrawalCredentials`, wiring owner.
- Tests: `DepositBufferedEther.t.sol` (unit + fuzz).
- **`forge test` → 66 PASS**.

---

### Fase 5 — WithdrawalQueue 🔒

**Objetivo:** ciclo completo request → finalize → claim.

1. TDD: request lockea shares; finalize quema/contabiliza; claim envía ETH con CEI.
2. Errores: not finalized, already claimed, not owner.
3. Integración con oracle/pool para fondear finalización.

**Criterio de salida:** lifecycle tests en verde.

---

### Fase 6 — Fuzz slash + invariantes 🔒

**Objetivo:** resiliencia ante yield negativo y solvencia del pool.

1. Fuzz negative yield: converter sin overflow; users pueden seguir withdraw path.
2. Invariante: `address(pool).balance + accounting >= sum claimable + buffer commitments` (definir precisamente en implementación).
3. Invariante: `sum(sharesOf) == totalShares`.

**Criterio de salida:** fuzz (>=1000) + invariantes en verde.

---

### Fase 7 — Gas + Deploy + cierre v1 🔒

**Objetivo:** deploy reproducible, NatSpec completo, gas snapshot, docs sync.

1. `Deploy.s.sol` + `.env.example`.
2. NatSpec en API pública; alinear diagramas si hubo desviaciones.
3. `forge snapshot` / gas report; eliminar stubs.
4. Marcar fases 0–7 ✅ en este documento.

**Criterio de salida:** deploy local OK; suite completa verde; planificación actualizada.

---

## 8. Checklist de aceptación global (v1)

- [ ] Dual-token `stETH` + `wstETH` operativo
- [ ] Oracle solo comité → `UnauthorizedOracle()`
- [ ] Rebase positivo y negativo cubiertos por tests
- [ ] WithdrawalQueue: request / finalize / claim
- [ ] Fee caps inmutables enforced
- [ ] ShareMath WAD/RAY sin lock de fondos en fuzz slash
- [ ] Integración mock Deposit Contract 32 ETH
- [ ] CEI + `.call{value}` + custom errors + NatSpec
- [ ] `forge test` (unit + fuzz + invariant) verde
- [ ] Frontend Next.js **no** incluido (post-v1)

---

## 9. Próximo paso

**Fase 4 cerrada.** Esperando autorización para la **Fase 5** (`WithdrawalQueue` request / finalize / claim).

Responde: **`Autorizo Fase 5`** para continuar.
