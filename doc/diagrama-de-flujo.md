# Diagrama de flujo — Deposit, oracle rebase y withdrawal queue

Flujos de decisión internos del protocolo de liquid staking (módulo 18, **v1 — diseño**).  
**Sync:** 2026-09-14.

## 1. submit (ETH → shares / stETH)

```mermaid
flowchart TD
    A[Usuario: submit + msg.value ETH] --> B{¿msg.value > 0?}
    B -->|No| Z0[Revert ZeroDeposit]
    B -->|Sí| C{¿paused?}
    C -->|Sí| Z1[Revert Paused]
    C -->|No| D[Calcular shares = ShareMath.ethToShares]
    D --> E{¿primer deposit totalShares=0?}
    E -->|Sí| F[shares = ethAmount - offset o 1:1]
    E -->|No| G[shares = eth * totalShares / totalPooledEther]
    F --> H[_mintShares recipient]
    G --> H
    H --> I[bufferedEther += msg.value]
    I --> J[Emit Submitted / Transfer]
    J --> Ok([Fin — OK: stETH balance rebasing])
    Z0 --> End([Fin — revert])
    Z1 --> End
```

> CEI: actualizar shares y buffer **antes** de cualquier llamada externa. ETH vía buffer interno (sin transfer out en submit).

---

## 2. depositBufferedEther → Eth2 Deposit Contract

```mermaid
flowchart TD
    A[Keeper / anyone: depositBufferedEther] --> B{¿bufferedEther >= 32 ETH?}
    B -->|No| Z0[Revert InsufficientBalance o no-op]
    B -->|Sí| C[Obtener N keys de NodeOperatorsRegistry]
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
    A[Oracle committee: submitReport] --> B{¿msg.sender / firmas autorizadas?}
    B -->|No| Z0[Revert UnauthorizedOracle]
    B -->|Sí| C{¿refSlot / timestamp válido?}
    C -->|No| Z1[Revert ReportTooEarly / InvalidReport]
    C -->|Sí| D[delta = newCLBalance + elRewards - prevBeacon - bufferedChange]
    D --> E{¿delta >= 0?}
    E -->|Sí positive| F[Calcular protocol fee sobre rewards]
    F --> G[Mint shares fee a treasury / operators]
    G --> H[beaconBalance = newCLBalance]
    H --> I[totalPooledEther implícito crece → rebase + stETH]
    E -->|No negative / slash| J{¿solvencia: pooledEth post >= min?}
    J -->|No| Z2[Revert NegativeRebaseBlocked o clamp]
    J -->|Sí| K[beaconBalance = newCLBalance]
    K --> L[totalPooledEther baja → rebase - stETH]
    I --> M[Emit OracleReport / Rebase]
    L --> M
    M --> Ok([Fin — OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
```

> `balanceOf(stETH)` de todos los holders se ajusta **sin transferencias** (shares fijas, rate variable).  
> `wstETH.balanceOf` **no** cambia; `stEthPerToken()` sí.

---

## 4. Wrap / unwrap wstETH

```mermaid
flowchart TD
    A[Usuario: wrap stETHAmount] --> B{¿allowance / balance OK?}
    B -->|No| Z0[Revert InsufficientBalance]
    B -->|Sí| C[Transfer stETH → WstETH]
    C --> D[sharesLocked = getSharesByPooledEth]
    D --> E[_mint wstETH = sharesLocked]
    E --> Ok1([Fin wrap OK])

    F[Usuario: unwrap wstETHAmount] --> G{¿balance wstETH OK?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Sí| H[_burn wstETH]
    H --> I[Transfer stETH = getPooledEthByShares]
    I --> Ok2([Fin unwrap OK])
    Z0 --> End([Fin — revert])
    Z1 --> End
```

---

## 5. Withdrawal queue — request → finalize → claim

```mermaid
flowchart TD
    A[Usuario: requestWithdrawals amounts] --> B{¿stETH balance / allowance OK?}
    B -->|No| Z0[Revert InsufficientBalance]
    B -->|Sí| C[Transfer stETH → WithdrawalQueue]
    C --> D[Lock shares; crear requestId++]
    D --> E[Emit WithdrawalRequested]
    E --> Wait[Espera finalización asíncrona]

    Wait --> F[Oracle/Pool: finalize lastRequestId]
    F --> G{¿ETH disponible en buffer / withdrawals?}
    G -->|No| Z1[Revert InsufficientBalance]
    G -->|Sí| H[Marcar requests finalizados; burn shares]
    H --> I[Reservar ETH para claims]
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

---

## 6. Fee split en rewards

```mermaid
flowchart TD
    A[Rewards detectados en oracle report] --> B[feeEther = rewards * protocolFeeBps / 10000]
    B --> C{¿protocolFeeBps <= MAX_CAP?}
    C -->|No| Z0[Revert FeeCapExceeded]
    C -->|Sí| D[Mint shares equivalentes a feeEther]
    D --> E[Parte treasury]
    E --> F[Parte node operators]
    F --> G[Resto accrues a stakers vía rate]
    G --> Ok([Holders stETH ven rebase neto])
    Z0 --> End([Fin — revert])
```
