# Flow diagram — Deposit, oracle rebase, and withdrawal queue

**Language:** English · [Español](./diagrama-de-flujo-ES.md)

Internal decision flows of the protocol (module 18, **v1 implemented**).  
**Sync:** 2026-09-14 · Phases **0–7** ✅ · 90 PASS.

## 1. submit (ETH → shares / stETH)

```mermaid
flowchart TD
    A[User: submit + msg.value ETH] --> B{msg.value > 0?}
    B -->|No| Z0[Revert ZeroDeposit]
    B -->|Yes| D[shares = ShareMath.ethToShares]
    D --> E{First deposit totalShares=0?}
    E -->|Yes| F[shares = ethAmount — 1:1 bootstrap]
    E -->|No| G[shares = eth * totalShares / totalPooledEther]
    F --> H[bufferedEther += msg.value; _mintShares]
    G --> H
    H --> J[Emit Submitted / Transfer / TransferShares]
    J --> Ok([End — OK: rebasing stETH balance])
    Z0 --> End([End — revert])
```

> CEI: update buffer and shares **before** any external call. ETH stays in the internal buffer (no outbound transfer in submit).  
> `Paused` exists in `LiquidStakingErrors` but is **not** wired in v1.

---

## 2. depositBufferedEther → Eth2 Deposit Contract

```mermaid
flowchart TD
    A[Keeper / anyone: depositBufferedEther maxDeposits] --> B{bufferedEther >= 32 ETH and maxDeposits > 0?}
    B -->|No| Z0[Return 0 / early exit]
    B -->|Yes| C[assignNextSigningKeys from NodeOperatorsRegistry]
    C --> D{Enough keys?}
    D -->|No| Z1[Revert NoSigningKeys]
    D -->|Yes| E[Loop: deposit 32 ETH to DepositContract]
    E --> F[depositedValidators += N]
    F --> G[bufferedEther -= N * 32 ETH]
    G --> H[Emit DepositedValidators]
    H --> Ok([End — OK])
    Z0 --> End([End])
    Z1 --> End
```

---

## 3. Oracle report — positive / negative rebase

```mermaid
flowchart TD
    A[Committee member: AccountingOracle.submitReport] --> B{members msg.sender?}
    B -->|No| Z0[Revert UnauthorizedOracle]
    B -->|Yes| C{block.timestamp >= last + reportInterval?}
    C -->|No| Z1[Revert ReportTooEarly]
    C -->|Yes| D[StETH.handleOracleReport — only if msg.sender == oracle]
    D --> E{elRewards consistent with ETH balance?}
    E -->|No| Z2[Revert InvalidReport]
    E -->|Yes| F[bufferedEther += elRewards; clBalance = newCL]
    F --> G{postTotal == 0 and shares > 0?}
    G -->|Yes| Z3[Revert NegativeRebaseBlocked]
    G -->|No| H{postTotal > preTotal?}
    H -->|Yes positive| I[feeOnReward + mint fee shares treasury/ops]
    I --> J[rate ↑ → stETH balance ↑]
    H -->|No slash / flat| K[rate ↓ or equal → stETH balance adjusts]
    J --> M[Emit OracleReported]
    K --> M
    M --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> v1 auth: **on-chain membership** (`msg.sender ∈ members`), no EIP-712 signatures nor multi-sig quorum.  
> `balanceOf(stETH)` adjusts without transfers (fixed shares, variable rate).  
> `wstETH.balanceOf` does **not** change; `stEthPerToken()` does.

---

## 4. Wrap / unwrap wstETH

```mermaid
flowchart TD
    A[User: wrap stETHAmount] --> B{Allowance / balance OK?}
    B -->|No| Z0[Revert InsufficientBalance / ERC20 fail]
    B -->|Yes| C[Transfer stETH → WstETH]
    C --> D[wstETHAmount = getSharesByPooledEth]
    D --> E[_mint wstETH = shares]
    E --> Ok1([End wrap OK])

    F[User: unwrap wstETHAmount] --> G{wstETH balance OK?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Yes| H[_burn wstETH]
    H --> I[Transfer stETH = getPooledEthByShares]
    I --> Ok2([End unwrap OK])
    Z0 --> End([End — revert])
    Z1 --> End
```

> 1 wstETH = 1 share. `receive()` on WstETH: ETH → `stETH.submit` → wrap.

---

## 5. Withdrawal queue — request → finalize → claim

```mermaid
flowchart TD
    A[User: requestWithdrawals amounts] --> B{stETH balance / allowance OK?}
    B -->|No| Z0[Revert InsufficientBalance]
    B -->|Yes| C[TransferFrom stETH → WithdrawalQueue]
    C --> D[Lock shares; create requestId++]
    D --> E[Emit WithdrawalRequested]
    E --> Wait[Wait for asynchronous finalization]

    Wait --> F[Finalizer: finalize lastRequestId]
    F --> G{Enough buffered ETH in StETH?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Yes| H[StETH.finalizeWithdrawals: burn shares + unlock ETH]
    H --> I[Mark requests finalized]
    I --> J[Emit WithdrawalsFinalized]

    J --> K[User: claimWithdrawal requestId]
    K --> L{Finalized and not claimed and owner?}
    L -->|No| Z2[Revert WithdrawalNotFinalized / AlreadyClaimed / NotOwner]
    L -->|Yes| M[isClaimed = true]
    M --> N[call value ETH to owner]
    N --> O{OK?}
    O -->|No| Z3[Revert EthTransferFailed]
    O -->|Yes| P[Emit WithdrawalClaimed]
    P --> Ok([End — OK])
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> CEI in claim: set `isClaimed` **before** `.call{value: ...}("")`.  
> `finalize`: `owner` **or** `finalizer` (deploy sets `finalizer = oracle`). The queue then calls `StETH.finalizeWithdrawals` (`OnlyWithdrawalQueue`).

---

## 6. Fee split on rewards

```mermaid
flowchart TD
    A[Rewards detected in handleOracleReport] --> B[feeEther = FeeDistributor.feeOnReward]
    B --> C[fee shares = ethToShares feeEther]
    C --> D[splitShares → treasury + nodeOperators]
    D --> E[_mintShares to each recipient]
    E --> F[Remainder accrues to stakers via rate]
    F --> Ok([stETH holders see net rebase])
```

> Cap validated in the `FeeDistributor` **constructor** (`FeeCapExceeded` if `protocolFeeBps > 1000`).
