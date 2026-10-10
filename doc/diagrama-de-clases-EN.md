# Class diagram — Liquid Staking & Staking Derivatives

**Language:** English · [Español](./diagrama-de-clases-ES.md)

Structural view aligned with the v1 implementation (module 18).  
**Sync:** 2026-09-14 · Phases **0–7** ✅ (v1 closed · 90 PASS).

> **Design note:** there is no separate `LiquidStakingPool.sol`. The pool is **`StETH`**, which implements `IStETH` + `ILiquidStakingPool` (+ `IWithdrawalFinalizer` in the same contract).

## Diagram (Mermaid)

```mermaid
classDiagram
    direction TB

    class ILiquidStakingPool {
        <<interface>>
        +handleOracleReport(clBalance, elRewards)
    }

    class IStETH {
        <<interface>>
        +submit() payable uint256
        +submit(referral) payable uint256
        +sharesOf(account) uint256
        +getTotalShares() uint256
        +getTotalPooledEther() uint256
        +balanceOf(account) uint256
        +getSharesByPooledEth(ethAmount) uint256
        +getPooledEthByShares(sharesAmount) uint256
        +transferShares(to, sharesAmount) uint256
        +transfer(to, amount) bool
        +approve(spender, amount) bool
        +allowance(owner, spender) uint256
        +transferFrom(from, to, amount) bool
    }

    class IWstETH {
        <<interface>>
        +wrap(stETHAmount) uint256
        +unwrap(wstETHAmount) uint256
        +stETH() address
        +stEthPerToken() uint256
        +tokensPerStEth() uint256
        +getWstETHByStETH(stETHAmount) uint256
        +getStETHByWstETH(wstETHAmount) uint256
    }

    class IWithdrawalQueue {
        <<interface>>
        +requestWithdrawals(amounts, owner) uint256[]
        +finalize(lastRequestIdToBeFinalized)
        +claimWithdrawal(requestId)
        +getLastRequestId() uint256
        +getLastFinalizedRequestId() uint256
        +getWithdrawalStatus(requestIds) WithdrawalRequestStatus[]
    }

    class IWithdrawalFinalizer {
        <<interface>>
        +finalizeWithdrawals(sharesAmount, ethAmount)
    }

    class IAccountingOracle {
        <<interface>>
        +pool() address
        +reportInterval() uint256
        +lastReportTimestamp() uint256
        +members(account) bool
        +memberCount() uint256
        +submitReport(clBalance, elRewards)
    }

    class IDepositContract {
        <<interface>>
        +deposit(pubkey, withdrawalCredentials, signature, depositDataRoot) payable
        +get_deposit_root() bytes32
        +get_deposit_count() bytes
    }

    class INodeOperatorsRegistry {
        <<interface>>
        +addNodeOperator(name, rewardAddress) uint256
        +addSigningKeys(operatorId, count, pubkeys, signatures)
        +assignNextSigningKeys(depositsCount) pubkeys, signatures
        +getUnusedSigningKeyCount() uint256
        +getNodeOperatorsCount() uint256
    }

    class LiquidStakingErrors {
        <<errors>>
        +UnauthorizedOracle()
        +ZeroDeposit()
        +InsufficientBalance()
        +InvalidReport()
        +ReportTooEarly()
        +NegativeRebaseBlocked()
        +WithdrawalNotFinalized()
        +WithdrawalAlreadyClaimed()
        +WithdrawalNotOwner()
        +FeeCapExceeded()
        +EthTransferFailed()
        +ZeroAddress()
        +Paused()
        +NoSigningKeys()
        +MathDivisionByZero()
        +OnlyPool()
        +OnlyWithdrawalQueue()
    }

    class ShareMath {
        <<library>>
        +WAD uint256
        +RAY uint256
        +ethToShares(ethAmount, totalEth, totalShares) uint256
        +sharesToEth(sharesAmount, totalEth, totalShares) uint256
        +mulDiv(a, b, denominator) uint256
        +shareRateRay(totalEth, totalShares) uint256
    }

    class FeeDistributor {
        +MAX_PROTOCOL_FEE_BPS uint16
        +protocolFeeBps uint16
        +treasuryShareBps uint16
        +treasury address
        +nodeOperators address
        +feeOnReward(reward) uint256
        +splitShares(feeShares) treasuryShares, operatorShares
    }

    class StETH {
        +bufferedEther uint256
        +clBalance uint256
        +depositedValidators uint256
        +oracle address
        +feeDistributor FeeDistributor
        +depositContract IDepositContract
        +operatorsRegistry INodeOperatorsRegistry
        +withdrawalQueue address
        +submit() payable uint256
        +handleOracleReport(newClBalance, elRewards)
        +depositBufferedEther(maxDeposits) uint256
        +finalizeWithdrawals(sharesAmount, ethAmount)
        +getTotalPooledEther() uint256
        +getBufferedEther() uint256
        +getClBalance() uint256
    }

    class WstETH {
        +stETH IStETH
        +wrap(stETHAmount) uint256
        +unwrap(wstETHAmount) uint256
        +receive() payable
        +stEthPerToken() uint256
        +tokensPerStEth() uint256
    }

    class AccountingOracle {
        +pool ILiquidStakingPool
        +reportInterval uint256
        +lastReportTimestamp uint256
        +members mapping
        +memberCount uint256
        +submitReport(clBalance, elRewards)
        +addMember(member)
        +removeMember(member)
    }

    class WithdrawalQueue {
        +stETH IStETH
        +finalizer IWithdrawalFinalizer
        +lastRequestId uint256
        +lastFinalizedRequestId uint256
        +requests mapping
        +requestWithdrawals(amounts, owner) uint256[]
        +finalize(lastRequestIdToBeFinalized)
        +claimWithdrawal(requestId)
        +setFinalizer(finalizer_)
    }

    class WithdrawalRequest {
        <<struct>>
        +address owner
        +uint256 shares
        +uint256 claimableEther
        +uint40 timestamp
        +bool isFinalized
        +bool isClaimed
    }

    class NodeOperatorsRegistry {
        +pool address
        +operators mapping
        +addNodeOperator(name, rewardAddress) uint256
        +addSigningKeys(operatorId, count, pubkeys, signatures)
        +assignNextSigningKeys(depositsCount) pubkeys, signatures
        +getUnusedSigningKeyCount() uint256
        +setPool(pool_)
    }

    class MockDepositContract {
        <<mock>>
        +depositCount uint256
        +deposit(...) payable
        +get_deposit_root() bytes32
        +get_deposit_count() bytes
    }

    ILiquidStakingPool <|.. StETH
    IStETH <|.. StETH
    IWithdrawalFinalizer <|.. StETH
    IWstETH <|.. WstETH
    IWithdrawalQueue <|.. WithdrawalQueue
    IAccountingOracle <|.. AccountingOracle
    IDepositContract <|.. MockDepositContract
    INodeOperatorsRegistry <|.. NodeOperatorsRegistry

    StETH --> ShareMath : uses
    StETH --> FeeDistributor : feeOnReward / splitShares
    StETH --> IDepositContract : deposit 32 ETH
    StETH --> INodeOperatorsRegistry : assignNextSigningKeys
    StETH --> AccountingOracle : only oracle reports
    StETH --> WithdrawalQueue : finalizeWithdrawals
    WstETH --> IStETH : wrap/unwrap
    WithdrawalQueue --> IStETH : lock shares
    WithdrawalQueue --> IWithdrawalFinalizer : burn+unlock
    WithdrawalQueue --> WithdrawalRequest : stores
    AccountingOracle --> ILiquidStakingPool : handleOracleReport
    AccountingOracle ..> LiquidStakingErrors : UnauthorizedOracle
    NodeOperatorsRegistry ..> LiquidStakingErrors : OnlyPool
```

## Responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `StETH` | Unified pool: submit → mint shares; buffer+CL; oracle; Eth2 deposits; `finalizeWithdrawals` |
| `WstETH` | Value-accruing wrapper: 1 wstETH = 1 share; wrap/unwrap; `receive()` ETH→submit+wrap |
| `AccountingOracle` | On-chain membership; interval; `submitReport` → `handleOracleReport` (no EIP-712 in v1) |
| `WithdrawalQueue` | `requestId` queue: lock shares → finalize → claim ETH (CEI) |
| `FeeDistributor` | Immutable 10% cap; `feeOnReward` + `splitShares` treasury/operators |
| `ShareMath` | `ethToShares` / `sharesToEth` / `mulDiv` / `shareRateRay` (WAD/RAY) |
| `NodeOperatorsRegistry` | Operators + 48/96 keys; `assignNextSigningKeys` pool-only |
| `IDepositContract` | Eth2 spec (`0x00000000219ab540356cBB839Cbe05303d7705Fa`); mock in lab |

## Dual-token model

```
                    ┌─────────────────────────────────────┐
                    │              StETH (pool)           │
                    │  pooled = bufferedEther + clBalance │
                    │  totalShares / share rate           │
                    └──────────────┬──────────────────────┘
                                   │
              shares-based         │         value-accruing
              (rebasing)           │         (wrapper)
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
              balanceOf(user)              WstETH.balanceOf(user)
              = shares * rate              = wrapped shares (fixed)
              rate = pooledEth/shares      stEthPerToken grows
```

## Custom errors (implemented)

| Error | Usage |
|-------|-------|
| `UnauthorizedOracle()` | Reporter ≠ `oracle` / not a member (`AccountingOracle`) |
| `ZeroDeposit()` | `msg.value == 0` on submit |
| `InvalidReport()` / `ReportTooEarly()` | Inconsistent EL rewards or interval |
| `NegativeRebaseBlocked()` | `pooled == 0` with `shares > 0` |
| `WithdrawalNotFinalized()` / `AlreadyClaimed()` / `NotOwner()` | Queue lifecycle |
| `FeeCapExceeded()` | Fee / treasuryShare above caps in constructor |
| `EthTransferFailed()` | Failed `.call{value}` |
| `ZeroAddress()` / `NoSigningKeys()` | Validations |
| `OnlyPool()` / `OnlyWithdrawalQueue()` | Cross-contract access control |
| `MathDivisionByZero()` | `ShareMath.mulDiv` |
| `Paused()` | Reserved (not wired in v1) |
