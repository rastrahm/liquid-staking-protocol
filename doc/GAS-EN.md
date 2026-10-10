# Gas optimization — Liquid Staking Protocol

**Language:** English · [Español](./GAS-ES.md)

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract LiquidStakingGasTest --gas-report
forge snapshot --match-contract LiquidStakingGasTest
```

**Baseline date:** 2026-09-14 (Phase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/LiquidStaking.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`, EVM Cancun

---

## Operation baseline (snapshot)

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_submit` | **41 691** | Mint shares + buffer |
| `testGas_wrap` | **111 534** | Approve + wrap 1 ETH |
| `testGas_unwrap` | **112 066** | Wrap+unwrap (includes wrap setup in the test) |
| `testGas_depositBufferedEther_oneValidator` | **493 067** | Keys + mock deposit 32 ETH |
| `testGas_oracleReport_positiveRebase` | **151 952** | CL + fee mint |
| `testGas_withdrawal_requestFinalizeClaim` | **222 232** | request → finalize → claim |

---

## Applied optimizations

| Technique | Where | Effect |
|-----------|-------|--------|
| Transient reentrancy (`tstore`) | StETH / WstETH / Queue | No SSTORE from the classic OZ guard |
| OZ `Math.mulDiv` (512-bit) | `ShareMath` | Overflow-safe without a custom FullMath |
| Immutable fee recipients / bps | `FeeDistributor` | Cheap reads / deploy-time caps |
| Custom errors | `LiquidStakingErrors` | vs `require` strings |
| CEI + single `.call{value}` | claim / finalizeWithdrawals | Fewer failure patterns |
| `maxDeposits` on keeper path | `depositBufferedEther` | Bounds loop gas |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Hot-path inlining |

### Tradeoffs

- **`via_ir = true`:** fine for this module (no heavy Poseidon assembly).
- **Deposit loop:** gas ∝ N validators; keepers should batch.
- **Oracle fee mint:** 1–2 extra `_mintShares` on positive rebase.

---

## References

- [`foundry.toml`](../foundry.toml)
- [`test/gas/LiquidStaking.gas.t.sol`](../test/gas/LiquidStaking.gas.t.sol)
- [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md)
