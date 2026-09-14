# Optimización de gas — Liquid Staking Protocol

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract LiquidStakingGasTest --gas-report
forge snapshot --match-contract LiquidStakingGasTest
```

**Fecha baseline:** 2026-09-14 (Fase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/LiquidStaking.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`, EVM Cancun

---

## Baseline operaciones (snapshot)

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_submit` | **41 691** | Mint shares + buffer |
| `testGas_wrap` | **111 534** | Approve + wrap 1 ETH |
| `testGas_unwrap` | **112 066** | Wrap+unwrap (incluye wrap prep en test) |
| `testGas_depositBufferedEther_oneValidator` | **493 067** | Keys + mock deposit 32 ETH |
| `testGas_oracleReport_positiveRebase` | **151 952** | CL + fee mint |
| `testGas_withdrawal_requestFinalizeClaim` | **222 232** | request → finalize → claim |

---

## Optimizaciones aplicadas

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| Transient reentrancy (`tstore`) | StETH / WstETH / Queue | Sin SSTORE del guard clásico OZ |
| OZ `Math.mulDiv` (512-bit) | `ShareMath` | Overflow-safe sin FullMath propio |
| Immutable fee recipients / bps | `FeeDistributor` | SLOAD barato / deploy-time caps |
| Custom errors | `LiquidStakingErrors` | vs `require` strings |
| CEI + single `.call{value}` | claim / finalizeWithdrawals | Menos patrones fallidos |
| `maxDeposits` en keeper path | `depositBufferedEther` | Acota gas del loop |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining hot paths |

### Tradeoffs

- **`via_ir = true`:** OK en este módulo (sin Poseidon assembly pesado).
- **Deposit loop:** gas ∝ N validadores; keepers deben batch-ear.
- **Oracle fee mint:** 1–2 `_mintShares` extra en rebase positivo.

---

## Referencias

- [`foundry.toml`](../foundry.toml)
- [`test/gas/LiquidStaking.gas.t.sol`](../test/gas/LiquidStaking.gas.t.sol)
- [SWC-AUDIT.md](./SWC-AUDIT.md)
