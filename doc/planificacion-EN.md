# Planning — Module 18: Liquid Staking & Staking Derivatives

**Language:** English · [Español](./planificacion-ES.md)

**Status:** Phases **0–7** ✅ (v1 module closed).  
**Progress rule:** the per-phase authorization rule applied during construction; v1 has no pending phases.  
**Suite:** `forge test` → **90 PASS**.

---

## 1. Goal

Build a stETH/wstETH-style **liquid staking** protocol that allows:

- Depositing ETH and receiving a **shares**-based **rebasing** token (`stETH`).
- Wrapping `stETH` into a **value-accruing** wrapper (`wstETH`) for DeFi composability.
- Integrating the **Eth2 Deposit Contract** (spec `0x00000000219ab540356cBB839Cbe05303d7705Fa`) to activate 32 ETH validators.
- Distributing rewards through an authorized **oracle** (CL balances + EL rewards) with positive rebase and **negative rebase** (slashing) without breaking solvency.
- Processing unstaking through an asynchronous **WithdrawalQueue** (`requestId`-backed).
- Applying a **fee split** with immutable caps between stakers, treasury, and node operators.
- Using **WAD (1e18) / RAY (1e27)** precision in shares ↔ ETH conversions.

Stack: **Foundry + Solidity `0.8.24`**. Next.js frontend is **out of v1 scope**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `StETH` = unified pool (rebasing shares + buffer + oracle + deposits) | Native multi-chain / L2 |
| `WstETH` value-accruing wrap/unwrap | stETH restaking (EigenLayer, etc.) |
| `depositBufferedEther` → Eth2 Deposit Contract (mock in lab) | Distributed Validator Technology (DVT) |
| `AccountingOracle` on-chain committee + `UnauthorizedOracle()` | Multi-signature quorum / EIP-712 reports |
| Request-ID `WithdrawalQueue` (no NFT) | NFT withdrawal tickets (optional post-v1) |
| `FeeDistributor` immutable caps | On-chain fee governance |
| `ShareMath` WAD/RAY + OZ `mulDiv` | Vaults / strategies on top of the LST |
| `NodeOperatorsRegistry` basic keys | Operator marketplace |
| Tests: unit + slash fuzz + invariants + gas | Next.js frontend (App Router) |
| `Deploy.s.sol` + `SWC-AUDIT` + `.gas-snapshot` | Mainnet production hardening / insurance |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuardTransient`, `Ownable2Step`, `ERC20`, `Math`).
- Foundry: unit + fuzz (`runs >= 1000`) + invariant + gas reports / snapshot.
- **Custom errors** (no `require` strings).
- Strict CEI; ETH via **`.call{value: ...}("")`** (never `transfer`/`send`).
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests first in contract phases.

### Module 18 (local `.cursorrules`)

- Dual-token: `stETH` (rebasing shares) + `wstETH` (wrapper).
- Restricted oracle → `error UnauthorizedOracle()`.
- Negative rebase (slashing) without locking funds or converter overflow.
- Asynchronous post-finality `WithdrawalQueue`.
- Immutable fee caps: operators / treasury / stakers.
- Math: Ray/Wad (`1e27` / `1e18`).
- Standard Eth2 Deposit Contract interface.

### Next.js (`nextjs.cursorrules`) — post-v1

- UI stake / wrap / request-withdraw / claim: App Router, Zod, Vitest + RTL, JSDoc, no `any`.
- Outside phases 0–7.

---

## 4. Architecture (v1 implemented)

```
18-liquid-staking-protocol/
├── README.md                          # Bilingual index
├── README-ES.md / README-EN.md
├── .cursorrules
├── .gitignore
├── .env.example
├── .gas-snapshot
├── foundry.toml
├── remappings.txt
├── portfolio/                         # Portfolio page (ES/EN)
├── doc/                               # Each document in -ES.md and -EN.md
│   ├── README.md                      # Bilingual documentation index
│   ├── README-ES.md / README-EN.md
│   ├── decisiones-tecnicas-y-logica-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   └── GAS-{ES,EN}.md
├── src/
│   ├── StETH.sol                      # Unified pool: shares + buffer + CL + deposits + finalizeWithdrawals
│   ├── WstETH.sol                     # Value-accruing wrapper (1 wstETH = 1 share)
│   ├── AccountingOracle.sol           # Committee + submitReport → handleOracleReport
│   ├── WithdrawalQueue.sol            # request → finalize → claim (+ IWithdrawalFinalizer)
│   ├── FeeDistributor.sol             # Fee bps + treasury/operators split
│   ├── NodeOperatorsRegistry.sol      # 48/96 signing keys
│   ├── interfaces/
│   │   ├── ILiquidStakingPool.sol     # handleOracleReport
│   │   ├── IStETH.sol
│   │   ├── IWstETH.sol
│   │   ├── IWithdrawalQueue.sol
│   │   ├── IAccountingOracle.sol
│   │   ├── IDepositContract.sol
│   │   └── INodeOperatorsRegistry.sol
│   ├── libraries/
│   │   └── ShareMath.sol
│   ├── errors/
│   │   └── LiquidStakingErrors.sol
│   └── mocks/
│       └── MockDepositContract.sol
├── test/
│   ├── ShareMath.t.sol
│   ├── StETH.t.sol
│   ├── WstETH.t.sol
│   ├── OracleReport.t.sol
│   ├── DepositBufferedEther.t.sol
│   ├── WithdrawalQueue.t.sol
│   ├── helpers/Harnesses.sol
│   ├── fuzz/SlashingResilience.t.sol
│   ├── invariant/
│   │   ├── LiquidStakingHandler.sol
│   │   └── PoolSolvency.invariant.t.sol
│   └── gas/LiquidStaking.gas.t.sol
└── script/
    └── Deploy.s.sol
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `StETH` | Submit ETH → mint shares; rebasing `balanceOf`; buffer+CL; oracle report; `depositBufferedEther`; `finalizeWithdrawals` |
| `WstETH` | Wrap/unwrap; `stEthPerToken` / `tokensPerStEth`; `receive()` ETH→submit+mint |
| `AccountingOracle` | Membership; interval; `submitReport` → pool |
| `WithdrawalQueue` | Lock shares; finalize (burn+unlock ETH); CEI claim |
| `FeeDistributor` | `feeOnReward` + `splitShares` (immutables + 10% cap) |
| `ShareMath` | `ethToShares` / `sharesToEth` / `mulDiv` / `shareRateRay` |
| `NodeOperatorsRegistry` | Operators + keys; `assignNextSigningKeys` pool-only |
| `MockDepositContract` | Lab Eth2 deposit (32 ETH) |

---

## 5. Custom errors (module)

```solidity
error UnauthorizedOracle();        // required (.cursorrules)
error ZeroDeposit();
error InsufficientBalance();
error InvalidReport();
error ReportTooEarly();
error NegativeRebaseBlocked();     // pooled=0 with shares>0
error WithdrawalNotFinalized();
error WithdrawalAlreadyClaimed();
error WithdrawalNotOwner();
error FeeCapExceeded();
error EthTransferFailed();
error ZeroAddress();
error Paused();                    // reserved (not wired in v1)
error NoSigningKeys();
error MathDivisionByZero();
error OnlyPool();                  // NodeOperatorsRegistry.assignNextSigningKeys
error OnlyWithdrawalQueue();       // StETH.finalizeWithdrawals
```

Module requirements: `UnauthorizedOracle()`, dual-token accounting, withdrawal queue lifecycle, fee caps, negative rebase handling.

### Initial parameters (v1 lab)

| Parameter | v1 value |
|-----------|----------|
| `MAX_PROTOCOL_FEE_BPS` | `1000` (10%) immutable |
| Precision | WAD `1e18`, RAY `1e27` (`shareRateRay`) |
| `DEPOSIT_SIZE` | `32 ether` |
| Oracle `reportInterval` | configurable (tests: `1 hours`; deploy env default `3600`) |
| Withdrawal mode | `requestId` (uint256), no NFT |
| Oracle auth | `msg.sender` ∈ `members` (no EIP-712 signatures in v1) |

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *“I authorize Phase N”*. |
| **Delivery** | On close: acceptance checklist + touched files. |
| **Blocking** | New scope → document and wait for new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry setup + structure + errors/math stub | ✅ Completed | ✅ Authorized |
| 1 | `ShareMath` + `StETH` submit/mint shares | ✅ Completed | ✅ Authorized |
| 2 | `WstETH` wrap/unwrap | ✅ Completed | ✅ Authorized |
| 3 | `AccountingOracle` + +/− rebase + fees | ✅ Completed | ✅ Authorized |
| 4 | `NodeOperatorsRegistry` + DepositContract integration | ✅ Completed | ✅ Authorized |
| 5 | `WithdrawalQueue` request / finalize / claim | ✅ Completed | ✅ Authorized |
| 6 | Security suite: slash fuzz + solvency invariants | ✅ Completed | ✅ Authorized |
| 7 | Gas + Deploy + NatSpec / v1 close | ✅ Completed | ✅ Authorized |

**How to authorize:** reply in chat with `Autorizo Fase N` / `I authorize Phase N` (or reject with concrete changes).

---

## 7. Phase details

### Phase 0 — Foundry setup + structure ✅

**Goal:** compilable repo with the module layout and stubs.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`).
2. Dependencies: `forge-std`, OpenZeppelin v5.
3. Folders `src/{interfaces,libraries,errors,mocks}`, `test/{fuzz,invariant,gas}`, `script/`.
4. `LiquidStakingErrors.sol` + `ShareMath` stub + `Placeholder` smoke test.
5. `.env.example`, `README.md`, `remappings.txt`.

**Exit criteria:** `forge build` and `forge test` green (smoke).

**Done (2026-09-14):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored): forge-std **v1.16.2**, OpenZeppelin **v5.2.0** (copied from module 16).
- Folders `src/{interfaces,libraries,errors,mocks}`, `test/{fuzz,invariant,gas,helpers}`, `script/`.
- `src/errors/LiquidStakingErrors.sol` — 15 custom errors (incl. `UnauthorizedOracle`, `MathDivisionByZero`).
- `src/libraries/ShareMath.sol` — WAD/RAY + `ethToShares` / `sharesToEth` / `mulDiv` stubs.
- `src/Placeholder.sol` stub + `test/Placeholder.t.sol` (ping, IERC20 remapping, ShareMath, oracle selector, fuzz).
- `script/Deploy.s.sol` stub (Phase 7); `.env.example`; `README.md`.
- `forge build` OK; `forge test` → **8 PASS** (fuzz 1000).

---

### Phase 1 — ShareMath + StETH submit ✅

**Goal:** ETH deposit → mint shares with the correct ratio under varying `totalPooledEther`.

1. TDD: `ethToShares` / `sharesToEth`; first deposit; later deposits with rate ≠ 1.
2. Minimal `StETH` / pool: `submit`, `sharesOf`, rebasing `balanceOf`, `getTotalPooledEther`.
3. `Submitted` / `Transfer` events; custom errors.
4. CEI + reentrancy guard on submit.

**Exit criteria:** deposit-to-share ratio unit + fuzz tests green.

**Done (2026-09-14):**
- `ShareMath`: WAD/RAY, `ethToShares` / `sharesToEth` / `mulDiv` / `shareRateRay` via OZ `Math.mulDiv` (512-bit).
- `IStETH` + `StETH`: `submit` / `receive`, rebasing shares, ERC-20 (`transfer`/`approve`/`transferFrom`), `transferShares`.
- Accounting: `bufferedEther + clBalance`; `ReentrancyGuardTransient`; CEI in `_submit`.
- Test harnesses: `ShareMathHarness`, `StETHHarness` (`simulateRewards` / `simulateLoss`).
- Tests: `ShareMath.t.sol`, `StETH.t.sol` (1:1 first deposit, +/− rebase, ratio fuzz).
- Removed `Placeholder` stub.
- **`forge test` → 29 PASS**.

---

### Phase 2 — WstETH wrapper ✅

**Goal:** wrap/unwrap with value parity and a non-rebasing ERC-20 balance.

1. TDD: wrap N stETH → unwrap returns ≈ N (dust tolerance); after a simulated rebase, `stEthPerToken` changes and `balanceOf(wstETH)` does not.
2. Approve/transfer stETH to the wrapper; mint/burn wstETH.
3. Views: `getWstETHByStETH`, `getStETHByWstETH`, `stEthPerToken`, `tokensPerStEth`.

**Exit criteria:** wrap/unwrap parity + post-rebase tests green.

**Done (2026-09-14):**
- `IWstETH` + `WstETH` (OZ `ERC20` + `ReentrancyGuardTransient`).
- `wrap` / `unwrap`; `receive()` ETH → `stETH.submit` + mint wstETH.
- Rate views; 1 wstETH = 1 share; balance does not rebase after rewards.
- Tests: `WstETH.t.sol` (parity, post-rebase, fuzz).
- **`forge test` → 44 PASS**.

---

### Phase 3 — Oracle + rebase + fees ✅

**Goal:** authorized reports update pooled ether; capped fees; safe negative rebase.

1. TDD: `UnauthorizedOracle` revert; positive rebase increases holders' `balanceOf`; negative rebase reduces it without underflow/lock.
2. `AccountingOracle` + `handleOracleReport` in the pool.
3. `FeeDistributor`: mint fee shares; `FeeCapExceeded`.
4. Minimum interval between reports.

**Exit criteria:** positive/negative rebase + oracle auth tests green.

**Done (2026-09-14):**
- `FeeDistributor`: `MAX_PROTOCOL_FEE_BPS=1000`, immutable treasury/operators split.
- `AccountingOracle`: committee, `submitReport`, interval, `UnauthorizedOracle` / `ReportTooEarly`.
- `StETH.handleOracleReport`: CL + EL rewards, Lido-style fee mint, `NegativeRebaseBlocked` if pooled=0 with shares.
- `Ownable2Step` + `setOracle` / `setFeeDistributor`.
- Tests: `OracleReport.t.sol`.
- **`forge test` → 57 PASS**.

---

### Phase 4 — Validators + Deposit Contract ✅

**Goal:** drain the buffer in multiples of 32 ETH into the deposit contract.

1. Mock `IDepositContract` + `NodeOperatorsRegistry` (keys).
2. `depositBufferedEther(maxDeposits)`.
3. `depositedValidators` counters / initial beacon balance tracking post-deposit.

**Exit criteria:** 32 ETH × N deposit tests and failure without keys/buffer.

**Done (2026-09-14):**
- `IDepositContract` + `MockDepositContract` (lab Eth2 deposit).
- `NodeOperatorsRegistry`: operators, 48/96 signing keys, pool-only `assignNextSigningKeys`.
- `StETH.depositBufferedEther`: buffer → deposit contract; provisional `clBalance`; pooled invariant.
- `depositedValidators`, `withdrawalCredentials`, owner wiring.
- Tests: `DepositBufferedEther.t.sol` (unit + fuzz).
- **`forge test` → 66 PASS**.

---

### Phase 5 — WithdrawalQueue ✅

**Goal:** full request → finalize → claim lifecycle.

1. TDD: request locks shares; finalize burns/accounts; claim sends ETH with CEI.
2. Errors: not finalized, already claimed, not owner.
3. Integration with oracle/pool to fund finalization.

**Exit criteria:** lifecycle tests green.

**Done (2026-09-14):**
- `IWithdrawalQueue` + `WithdrawalQueue` (request-id, owner/finalizer).
- `StETH.finalizeWithdrawals` — burns queue shares + unlocks buffer ETH (queue-only).
- Claim with CEI + `.call{value}`; errors `WithdrawalNotFinalized` / `AlreadyClaimed` / `NotOwner`.
- Tests: `WithdrawalQueue.t.sol` (lifecycle, post-request rebase, fuzz).
- **`forge test` → 75 PASS**.

---

### Phase 6 — Slash fuzz + invariants ✅

**Goal:** resilience against negative yield and pool solvency.

1. Negative-yield fuzzing: converter without overflow; users can still use the withdraw path.
2. Invariant: `address(pool).balance + accounting >= sum claimable + buffer commitments` (defined precisely during implementation).
3. Invariant: `sum(sharesOf) == totalShares`.

**Exit criteria:** fuzz (>=1000) + invariants green.

**Done (2026-09-14):**
- `test/fuzz/SlashingResilience.t.sol` — converters, post-slash submit, withdraw path, no soft-lock.
- `test/invariant/LiquidStakingHandler.sol` + `PoolSolvency.invariant.t.sol`:
  - shares conserved (actors + queue)
  - `balance(pool) >= bufferedEther`
  - Σ balances ≤ total pooled
  - pooled > 0 when shares exist
- **`forge test` → 84 PASS** (invariants 256 runs × 15 depth).

---

### Phase 7 — Gas + Deploy + v1 close ✅

**Goal:** reproducible deploy, complete NatSpec, gas snapshot, docs sync.

1. `Deploy.s.sol` + `.env.example`.
2. NatSpec on public API; align diagrams if there were deviations.
3. `forge snapshot` / gas report; remove stubs.
4. Mark phases 0–7 ✅ in this document.

**Exit criteria:** local deploy OK; full suite green; planning updated.

**Done (2026-09-14):**
- `script/Deploy.s.sol` — StETH, WstETH, FeeDistributor, Oracle, Queue, Registry, MockDeposit + wiring.
- Extended `.env.example`; `test/gas/LiquidStaking.gas.t.sol` + `.gas-snapshot`.
- `doc/SWC-AUDIT-EN.md` (SWC-100–136 matrix, module 01 style); `doc/GAS-EN.md`; `doc/README.md`.
- Diagrams + planning realigned with code (pool = `StETH`, real APIs, no `LiquidStakingPool` / `MockOracle`).
- Bilingual documentation: each file in `-ES.md` / `-EN.md`, with `README.md` as index.
- **`forge test` → 90 PASS**.

---

## 8. Global acceptance checklist (v1)

- [x] Dual-token `stETH` + `wstETH` operational
- [x] Committee-only oracle → `UnauthorizedOracle()`
- [x] Positive and negative rebase covered by tests
- [x] WithdrawalQueue: request / finalize / claim
- [x] Immutable fee caps enforced
- [x] ShareMath WAD/RAY without fund lock under slash fuzzing
- [x] Mock Deposit Contract 32 ETH integration
- [x] CEI + `.call{value}` + custom errors + NatSpec
- [x] `forge test` (unit + fuzz + invariant) green
- [x] Next.js frontend **not** included (post-v1)
- [x] `doc/SWC-AUDIT-EN.md` (module 01 style)
- [x] Gas snapshot + `Deploy.s.sol`

---

## 9. Next step

**v1 module closed (Phases 0–7 ✅).**  
Optional post-v1: Next.js frontend, oracle quorum/EIP-712 signatures, real Eth2 deposit data root, NFT withdrawal tickets.
