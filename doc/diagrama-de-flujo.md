# Diagrama de flujo — Deposit, oracle rebase y withdrawal queue

Flujos de decisión internos del protocolo (módulo 18, **v1 implementado**).  
**Sync:** 2026-09-14 · Fases **0–7** ✅ · 90 PASS.

## 1. submit (ETH → shares / stETH)

```mermaid
flowchart TD
    A[Usuario: submit + msg.value ETH] --> B{¿msg.value > 0?}
    B -->|No| Z0[Revert ZeroDeposit]
    B -->|Sí| D[shares = ShareMath.ethToShares]
    D --> E{¿primer deposit totalShares=0?}
    E -->|Sí| F[shares = ethAmount — bootstrap 1:1]
    E -->|No| G[shares = eth * totalShares / totalPooledEther]
    F --> H[bufferedEther += msg.value; _mintShares]
    G --> H
    H --> J[Emit Submitted / Transfer / TransferShares]
    J --> Ok([Fin — OK: stETH balance rebasing])
    Z0 --> End([Fin — revert])
```

> CEI: actualizar buffer y shares **antes** de cualquier llamada externa. ETH vía buffer interno (sin transfer out en submit).  
> `Paused` existe en `LiquidStakingErrors` pero **no** está cableado en v1.

---

## 2. depositBufferedEther → Eth2 Deposit Contract

```mermaid
flowchart TD
    A[Keeper / anyone: depositBufferedEther maxDeposits] --> B{¿bufferedEther >= 32 ETH y maxDeposits > 0?}
    B -->|No| Z0[Return 0 / early exit]
    B -->|Sí| C[assignNextSigningKeys de NodeOperatorsRegistry]
    C --> D{¿hay keys suficientes?}
    D -->|No| Z1[Revert NoSigningKeys]
    D -->|Sí| E[Loop: deposit 32 ETH al DepositContract]
    E --> F[depositedValidators += N]
    F --> G[bufferedEther -= N * 32 ETH]
    G --> H[Emit DepositedValidators]
    H --> Ok([Fin — OK])
    Z0 --> End([Fin])
    Z1 --> End
```

---

## 3. Oracle report — positive / negative rebase

```mermaid
flowchart TD
    A[Miembro comité: AccountingOracle.submitReport] --> B{¿members msg.sender?}
    B -->|No| Z0[Revert UnauthorizedOracle]
    B -->|Sí| C{¿block.timestamp >= last + reportInterval?}
    C -->|No| Z1[Revert ReportTooEarly]
    C -->|Sí| D[StETH.handleOracleReport — solo si msg.sender == oracle]
    D --> E{¿elRewards y balance ETH coherentes?}
    E -->|No| Z2[Revert InvalidReport]
    E -->|Sí| F[bufferedEther += elRewards; clBalance = newCL]
    F --> G{¿postTotal == 0 y shares > 0?}
    G -->|Sí| Z3[Revert NegativeRebaseBlocked]
    G -->|No| H{¿postTotal > preTotal?}
    H -->|Sí positive| I[feeOnReward + mint fee shares treasury/ops]
    I --> J[rate ↑ → stETH balance ↑]
    H -->|No slash / flat| K[rate ↓ o igual → stETH balance ajusta]
    J --> M[Emit OracleReported]
    K --> M
    M --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> Auth v1: **membership on-chain** (`msg.sender ∈ members`), sin firmas EIP-712 ni quorum multi-sig.  
> `balanceOf(stETH)` se ajusta sin transferencias (shares fijas, rate variable).  
> `wstETH.balanceOf` **no** cambia; `stEthPerToken()` sí.

---

## 4. Wrap / unwrap wstETH

```mermaid
flowchart TD
    A[Usuario: wrap stETHAmount] --> B{¿allowance / balance OK?}
    B -->|No| Z0[Revert InsufficientBalance / ERC20 fail]
    B -->|Sí| C[Transfer stETH → WstETH]
    C --> D[wstETHAmount = getSharesByPooledEth]
    D --> E[_mint wstETH = shares]
    E --> Ok1([Fin wrap OK])

    F[Usuario: unwrap wstETHAmount] --> G{¿balance wstETH OK?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Sí| H[_burn wstETH]
    H --> I[Transfer stETH = getPooledEthByShares]
    I --> Ok2([Fin unwrap OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
```

> 1 wstETH = 1 share. `receive()` en WstETH: ETH → `stETH.submit` → wrap.

---

## 5. Withdrawal queue — request → finalize → claim

```mermaid
flowchart TD
    A[Usuario: requestWithdrawals amounts] --> B{¿stETH balance / allowance OK?}
    B -->|No| Z0[Revert InsufficientBalance]
    B -->|Sí| C[TransferFrom stETH → WithdrawalQueue]
    C --> D[Lock shares; crear requestId++]
    D --> E[Emit WithdrawalRequested]
    E --> Wait[Espera finalización asíncrona]

    Wait --> F[Finalizer: finalize lastRequestId]
    F --> G{¿ETH buffer suficiente en StETH?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Sí| H[StETH.finalizeWithdrawals: burn shares + unlock ETH]
    H --> I[Marcar requests finalizados]
    I --> J[Emit WithdrawalsFinalized]

    J --> K[Usuario: claimWithdrawal requestId]
    K --> L{¿finalized y !claimed y owner?}
    L -->|No| Z2[Revert WithdrawalNotFinalized / AlreadyClaimed / NotOwner]
    L -->|Sí| M[isClaimed = true]
    M --> N[call value ETH a owner]
    N --> O{¿OK?}
    O -->|No| Z3[Revert EthTransferFailed]
    O -->|Sí| P[Emit WithdrawalClaimed]
    P --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
```

> CEI en claim: marcar `isClaimed` **antes** de `.call{value: ...}("")`.  
> `finalize`: `owner` **o** `finalizer` (deploy setea `finalizer = oracle`). Luego la queue llama `StETH.finalizeWithdrawals` (`OnlyWithdrawalQueue`).

---

## 6. Fee split en rewards

```mermaid
flowchart TD
    A[Rewards detectados en handleOracleReport] --> B[feeEther = FeeDistributor.feeOnReward]
    B --> C[shares fee = ethToShares feeEther]
    C --> D[splitShares → treasury + nodeOperators]
    D --> E[_mintShares a cada destinatario]
    E --> F[Resto accrues a stakers vía rate]
    F --> Ok([Holders stETH ven rebase neto])
```

> Cap validado en **constructor** de `FeeDistributor` (`FeeCapExceeded` si `protocolFeeBps > 1000`).
