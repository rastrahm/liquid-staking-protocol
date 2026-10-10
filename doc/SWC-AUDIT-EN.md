# SWC Audit — Liquid Staking & Staking Derivatives

**Language:** English · [Español](./SWC-AUDIT-ES.md)

Verification of the liquid staking protocol (module 18) against the [SWC Registry](https://swcregistry.io/) (EIP-1470). Style aligned with [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/StETH.sol`,  
`src/WstETH.sol`,  
`src/AccountingOracle.sol`,  
`src/WithdrawalQueue.sol`,  
`src/FeeDistributor.sol`,  
`src/NodeOperatorsRegistry.sol`,  
`src/libraries/ShareMath.sol`,  
`src/errors/LiquidStakingErrors.sol`,  
`src/interfaces/*`

**Trusted dependencies:** forge-std, OpenZeppelin Contracts v5.2 (`ReentrancyGuardTransient`, `Ownable2Step`, `ERC20`, `Math`)

**Mocks (out of prod):** `MockDepositContract`, test harnesses  
**Date:** 2026-09-14 (Phase 7 / v1 close)  
**Test references:** `test/StETH.t.sol`, `test/WstETH.t.sol`, `test/OracleReport.t.sol`, `test/DepositBufferedEther.t.sol`, `test/WithdrawalQueue.t.sol`, `test/fuzz/SlashingResilience.t.sol`, `test/invariant/PoolSolvency.invariant.t.sol`, `test/gas/`  
**Index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 31 |
| ⚠️ Informational (LST design / oracle trust / ops) | 5 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities in v1 scope. The pool uses **`ReentrancyGuardTransient`**, **CEI** in submit / finalizeWithdrawals / claim, an **oracle gate** (`UnauthorizedOracle`), **immutable fee caps**, **WAD/RAY** conversions via OZ `mulDiv`, asynchronous withdrawals with **burn+unlock**, and fixed pragma **`0.8.24`**. Informational risks: trust in the oracle committee, ERC-20 approval front-running, finalize depending on buffer liquidity, lab deposit data root (mock), and share-rate flooring dust.

**Suite / module 18 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `LiquidStakingErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + reentrancy guard | ✅ Transient + CEI in claim/finalize |
| ETH `.call{value}` (no `transfer`/`send`) | ✅ claim / finalizeWithdrawals |
| Dual-token stETH + wstETH | ✅ |
| `UnauthorizedOracle()` | ✅ |
| Negative rebase without soft-lock | ✅ + fuzz/invariants |
| WithdrawalQueue request/finalize/claim | ✅ |
| Immutable fee caps | ✅ `MAX_PROTOCOL_FEE_BPS=1000` |
| Fuzz ≥ 1000 + invariants | ✅ `foundry.toml` |

---

## Full SWC-100 — SWC-136 matrix

| ID | Title | Applies | Status | Evidence in liquid staking |
|----|-------|---------|--------|----------------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; OZ `Math.mulDiv`; checks before buffer/shares subtractions |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | `.call{value}` checks `ok` → `EthTransferFailed` |
| SWC-105 | Unprotected Ether Withdrawal | Yes | ✅ | ETH leaves only via `WithdrawalQueue.claimWithdrawal` (owner+finalized) or Eth2 deposits |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `ReentrancyGuardTransient` on submit/report/deposit/wrap/unwrap/finalize/claim; CEI in claim |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `private` / `internal` / `public` / `immutable` |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Claim/finalize revert if the recipient rejects ETH; no inconsistent state left (CEI) |
| SWC-114 | Transaction Order Dependence | Yes | ⚠️ | `approve` / withdrawal queue front-running — see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth via `Ownable2Step`, oracle membership, finalizer; no `tx.origin` |
| SWC-116 | Block values as a proxy for time | Partial | ✅ | `block.timestamp` for report interval and request timestamps (accepted use) |
| SWC-117 | Signature Malleability | Partial | ⚠️ | v1 has no ECDSA multisig reports (auth by member `msg.sender`) — see risks |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing (`owner_` in params) |
| SWC-120 | Weak Sources of Randomness | No | N/A | No on-chain RNG |
| SWC-121 | Missing Protection against Signature Replay | Partial | ✅ | Equivalent: report interval + membership; one-shot withdrawals by `requestId` |
| SWC-122 | Lack of Proper Signature Verification | Partial | ⚠️ | Reports are not signed off-chain in v1 (caller = member) — see risks |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + auth/rebase/queue/fee tests |
| SWC-124 | Write to Arbitrary Storage Location | No | N/A | No arbitrary storage assembly |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | `IStETH, ILiquidStakingPool, Ownable2Step, ReentrancyGuardTransient` |
| SWC-126 | Insufficient Gas Griefing | Partial | ✅ | Keeper `depositBufferedEther` bounded by `maxDeposits`; O(N) loops with small N |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ✅ | Deposit/finalize loops bounded by input; registry keys per operator |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge test` |
| SWC-130 | Right-To-Left-Override control character | No | N/A | ASCII in NatSpec/tests |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead variables |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | Invariant `balance >= bufferedEther`; ETH donations increase balance without minting (no share dilution) |
| SWC-133 | Hash Collisions With Multiple Variable Length Arguments | Partial | ✅ | Lab `depositDataRoot` = `keccak256(abi.encodePacked(...))` (mock does not verify SSZ) — see risks |
| SWC-134 | Message call with hardcoded gas amount | No | N/A | No `.call{gas: ...}` |
| SWC-135 | Code With No Effects | No | N/A | No relevant empty statements |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Balances/shares public by LST design; on-chain signing keys are public |

---

## Informational risks

### SWC-114 — `approve` / request front-running

**Description:** A third party can front-run ERC-20 allowance changes on `stETH`/`wstETH`. In the queue, a request visible in the mempool does not transfer claim rights (owner is fixed), but it can compete for buffer liquidity at `finalize`.

**Status:** ⚠️ Inherent to ERC-20 / asynchronous queue design.

**Mitigations:**
- Prefer `transferShares` / minimal approvals; wrapping via `receive()` avoids approve when depositing ETH directly into `wstETH`.
- Permissioned finalize (`owner` / `finalizer`).
- Tests for insufficient allowance and `NotOwner` claim.

### SWC-117 / SWC-122 — Oracle without aggregated off-chain signatures

**Description:** v1 authorizes reports if `msg.sender` is a committee member (`AccountingOracle.members`). There is no multi-signature quorum nor EIP-712 payloads.

**Status:** ⚠️ Lab design / trust in an on-chain committee.

**Mitigations:**
- `UnauthorizedOracle` in pool and oracle; `ReportTooEarly` interval.
- `Ownable2Step` owner manages membership.
- Post-v1: quorum + EIP-712 signatures over the report hash.

### SWC-133 — Lab `depositDataRoot`

**Description:** The root sent to the deposit contract is a convenience `keccak256`; the mock does not validate BLS/SSZ. Mainnet would require the canonical Eth2 root.

**Status:** ⚠️ Acceptable with `MockDepositContract`; do not use as-is against the real deposit contract without the correct root.

**Mitigation:** `USE_MOCK_DEPOSIT=1` by default in `Deploy.s.sol`; document `DEPOSIT_CONTRACT` + off-chain root for prod.

### Buffer liquidity vs CL (ops)

**Description:** `finalize` requires sufficient `bufferedEther` (and balance). ETH already deposited to validators is not liquid until EL/CL returns.

**Status:** ⚠️ Operational / asynchronous by LST design.

**Mitigation:** `InsufficientBalance` tests on finalize; the keeper must keep buffer or wait for beacon withdrawals (out of v1).

### Share dust / flooring (residual SWC-101)

**Description:** `eth ↔ shares` conversions floor; the sum of `balanceOf` can be ≤ `totalPooledEther` by 1–2 wei per holder.

**Status:** ⚠️ Expected in shares-based accounting.

**Mitigation:** OZ `mulDiv`; round-trip fuzzing; invariant `sumBalances ≤ pooled`.

---

## SWC → tests mapping

| SWC | Related test(s) |
|-----|-----------------|
| SWC-101 | `ShareMath.t.sol` round-trip fuzz; `SlashingResilience.t.sol` |
| SWC-103 | Fixed compiler (`forge build`) |
| SWC-104 / ETH call | `WithdrawalQueue.t.sol` claim lifecycle |
| SWC-105 | `test_claim_notOwner_reverts`, `test_finalizeWithdrawals_onlyQueue` |
| SWC-107 | CEI claim/finalize; `ReentrancyGuardTransient` on hot paths |
| SWC-114 | Approve + `transferFrom` tests in `StETH.t.sol` / `WstETH.t.sol` |
| SWC-116 | `test_reportTooEarly_reverts` |
| SWC-121 / auth | `OracleReport.t.sol` UnauthorizedOracle / membership |
| SWC-123 | Fee cap, queue errors, deposit keys |
| SWC-132 | `invariant_BufferSolvency` |

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Eth2 Deposit Contract: `0x00000000219ab540356cBB839Cbe05303d7705Fa`
- Lido-style shares accounting (educational design reference)
- [`01-erc20/doc/SWC-AUDIT-EN.md`](../../01-erc20/doc/SWC-AUDIT-EN.md)
