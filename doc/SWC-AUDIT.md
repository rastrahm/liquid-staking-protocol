# Auditoría SWC — Liquid Staking & Staking Derivatives

Verificación del protocolo de liquid staking (módulo 18) contra el [SWC Registry](https://swcregistry.io/) (EIP-1470). Estilo alineado a [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
`src/StETH.sol`,  
`src/WstETH.sol`,  
`src/AccountingOracle.sol`,  
`src/WithdrawalQueue.sol`,  
`src/FeeDistributor.sol`,  
`src/NodeOperatorsRegistry.sol`,  
`src/libraries/ShareMath.sol`,  
`src/errors/LiquidStakingErrors.sol`,  
`src/interfaces/*`

**Dependencias de confianza:** forge-std, OpenZeppelin Contracts v5.2 (`ReentrancyGuardTransient`, `Ownable2Step`, `ERC20`, `Math`)

**Mocks (fuera de prod):** `MockDepositContract`, harnesses de test  
**Fecha:** 2026-09-14 (Fase 7 / cierre v1)  
**Referencia tests:** `test/StETH.t.sol`, `test/WstETH.t.sol`, `test/OracleReport.t.sol`, `test/DepositBufferedEther.t.sol`, `test/WithdrawalQueue.t.sol`, `test/fuzz/SlashingResilience.t.sol`, `test/invariant/PoolSolvency.invariant.t.sol`, `test/gas/`  
**Índice:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 31 |
| ⚠️ Informativo (diseño LST / trust oracle / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. El pool usa **`ReentrancyGuardTransient`**, **CEI** en submit / finalizeWithdrawals / claim, **oracle gated** (`UnauthorizedOracle`), **fee caps inmutables**, conversiones **WAD/RAY** vía OZ `mulDiv`, withdrawals asíncronos con **burn+unlock** y pragma fijo **`0.8.24`**. Riesgos informativos: confianza en el comité oracle, front-running de approvals ERC-20, finalize condicionado a liquidez de buffer, deposit data root lab (mock), y tasa de shares con dust de flooring.

**Principios del suite / módulo 18 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `LiquidStakingErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + reentrancy guard | ✅ Transient + CEI en claim/finalize |
| ETH `.call{value}` (no `transfer`/`send`) | ✅ claim / finalizeWithdrawals |
| Dual-token stETH + wstETH | ✅ |
| `UnauthorizedOracle()` | ✅ |
| Negative rebase sin soft-lock | ✅ + fuzz/invariantes |
| WithdrawalQueue request/finalize/claim | ✅ |
| Fee caps inmutables | ✅ `MAX_PROTOCOL_FEE_BPS=1000` |
| Fuzz ≥ 1000 + invariantes | ✅ `foundry.toml` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en liquid staking |
|----|--------|--------|--------|-----------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; OZ `Math.mulDiv`; checks antes de restas de buffer/shares |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | `.call{value}` chequea `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Sí | ✅ | ETH sale solo vía `WithdrawalQueue.claimWithdrawal` (owner+finalized) o depósitos Eth2 |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `ReentrancyGuardTransient` en submit/report/deposit/wrap/unwrap/finalize/claim; CEI en claim |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | `private` / `internal` / `public` / `immutable` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Claim/finalize revierten si recipient rechaza ETH; no deja estado inconsistente (CEI) |
| SWC-114 | Transaction Order Dependence | Sí | ⚠️ | Front-running `approve` / cola de withdraw — ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth vía `Ownable2Step`, oracle membership, finalizer; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | Parcial | ✅ | `block.timestamp` para intervalo de reportes y timestamps de requests (uso aceptado) |
| SWC-117 | Signature Malleability | Parcial | ⚠️ | v1 sin multisig ECDSA de reportes (auth por `msg.sender` miembro) — ver riesgos |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material (`owner_` en params) |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG on-chain |
| SWC-121 | Missing Protection against Signature Replay | Parcial | ✅ | Equivalente: intervalo de reportes + membership; withdrawals por `requestId` one-shot |
| SWC-122 | Lack of Proper Signature Verification | Parcial | ⚠️ | Reportes no firmados off-chain en v1 (caller = miembro) — ver riesgos |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + tests de auth/rebase/queue/fees |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | Sin assembly de storage arbitrario |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | `IStETH, ILiquidStakingPool, Ownable2Step, ReentrancyGuardTransient` |
| SWC-126 | Insufficient Gas Griefing | Parcial | ✅ | Keeper `depositBufferedEther` acotado por `maxDeposits`; loops O(N) con N pequeño |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ✅ | Loops de deposit/finalize acotados por input; registry keys por operador |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII en NatSpec/tests |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin variables muertas materiales |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | Invariante `balance >= bufferedEther`; donaciones ETH aumentan balance sin mint (no diluyen shares) |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Parcial | ✅ | `depositDataRoot` lab = `keccak256(abi.encodePacked(...))` (mock no verifica SSZ) — ver riesgos |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | Sin `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | Sin statements vacíos relevantes |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Balances/shares públicos por diseño LST; signing keys on-chain son públicas |

---

## Riesgos informativos

### SWC-114 — Front-running de `approve` / requests

**Descripción:** Un tercero puede frontrunear cambios de allowance ERC-20 sobre `stETH`/`wstETH`. En la cola, un request visible en mempool no transfiere derechos de claim (owner fijado), pero sí puede competir por liquidez de buffer en `finalize`.

**Estado:** ⚠️ Inherente a ERC-20 / diseño de cola asíncrona.

**Mitigaciones:**
- Preferir `transferShares` / approvals mínimas; wrap vía `receive()` evita approve cuando se deposita ETH directo a `wstETH`.
- Finalize permissioned (`owner` / `finalizer`).
- Tests de allowance insuficiente y claim `NotOwner`.

### SWC-117 / SWC-122 — Oracle sin firmas agregadas off-chain

**Descripción:** v1 autoriza reportes si `msg.sender` es miembro del comité (`AccountingOracle.members`). No hay quorum multi-firma ni EIP-712 de payloads.

**Estado:** ⚠️ Diseño lab / trust en comité on-chain.

**Mitigaciones:**
- `UnauthorizedOracle` en pool y oracle; intervalo `ReportTooEarly`.
- Owner `Ownable2Step` para membresía.
- Post-v1: quorum + firmas EIP-712 del report hash.

### SWC-133 — `depositDataRoot` de laboratorio

**Descripción:** El root enviado al deposit contract es un `keccak256` de conveniencia; el mock no valida SSZ BLS. En mainnet haría falta el root canónico Eth2.

**Estado:** ⚠️ Aceptable con `MockDepositContract`; no usar tal cual contra el deposit contract real sin root correcto.

**Mitigación:** `USE_MOCK_DEPOSIT=1` por defecto en `Deploy.s.sol`; documentar `DEPOSIT_CONTRACT` + root off-chain para prod.

### Liquidez de buffer vs CL (ops)

**Descripción:** `finalize` requiere `bufferedEther` (y balance) suficientes. ETH ya depositado a validadores no está líquido hasta retornos EL/CL.

**Estado:** ⚠️ Operacional / asíncrono por diseño LST.

**Mitigación:** Tests de `InsufficientBalance` en finalize; keeper debe mantener buffer o esperar withdrawals beacon (fuera de v1).

### Dust / flooring de shares (SWC-101 residual)

**Descripción:** Conversiones `eth ↔ shares` floorean; la suma de `balanceOf` puede ser ≤ `totalPooledEther` en 1–2 wei por holder.

**Estado:** ⚠️ Esperado en contabilidad shares-based.

**Mitigación:** OZ `mulDiv`; fuzz round-trip; invariante `sumBalances ≤ pooled`.

---

## Mapeo SWC → tests

| SWC | Test(s) relacionado(s) |
|-----|------------------------|
| SWC-101 | `ShareMath.t.sol` fuzz round-trip; `SlashingResilience.t.sol` |
| SWC-103 | Compilador fijo (`forge build`) |
| SWC-104 / ETH call | `WithdrawalQueue.t.sol` claim lifecycle |
| SWC-105 | `test_claim_notOwner_reverts`, `test_finalizeWithdrawals_onlyQueue` |
| SWC-107 | CEI claim/finalize; `ReentrancyGuardTransient` en hot paths |
| SWC-114 | Approve + `transferFrom` tests en `StETH.t.sol` / `WstETH.t.sol` |
| SWC-116 | `test_reportTooEarly_reverts` |
| SWC-121 / auth | `OracleReport.t.sol` UnauthorizedOracle / membership |
| SWC-123 | Fee cap, queue errors, deposit keys |
| SWC-132 | `invariant_BufferSolvency` |

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Eth2 Deposit Contract: `0x00000000219ab540356cBB839Cbe05303d7705Fa`
- Lido-style shares accounting (referencia de diseño educativa)
- [`01-erc20/doc/SWC-AUDIT.md`](../../01-erc20/doc/SWC-AUDIT.md)
