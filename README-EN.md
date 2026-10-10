# 18 — Liquid Staking & Staking Derivatives

**Language:** English · [Español](./README-ES.md)

stETH/wstETH-style liquid staking protocol: rebasing shares, value-accruing wrapper, rewards/slashing oracle, asynchronous withdrawal queue, and Eth2 deposits. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–7** ✅ (v1 module closed).  
**Suite:** `forge test` → **90 PASS**.

## Docs

| File | Content |
|------|---------|
| [`doc/README-EN.md`](./doc/README-EN.md) | Documentation index |
| [`doc/decisiones-tecnicas-y-logica-EN.md`](./doc/decisiones-tecnicas-y-logica-EN.md) | Design decisions, logic, and gas improvements |
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | Phases, architecture, criteria |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | UML |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Submit / oracle / queue |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | End-to-end cycle |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | Optimizations + snapshot |

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std **v1.16.2**, OpenZeppelin **v5.2.0** in `lib/` |
| Math | WAD `1e18` / RAY `1e27` (`ShareMath` + OZ `mulDiv`) |
| Guard | `ReentrancyGuardTransient` (Cancun) |
| EVM | Cancun (`via_ir = true`) |

## Foundry setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencies (already in `lib/`; reinstall if needed):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copy `.env.example` → `.env`.

## Gas

```bash
forge test --match-contract LiquidStakingGasTest --gas-report
forge snapshot --match-contract LiquidStakingGasTest
```

## v1 scope

- `StETH` = unified pool (rebasing shares + buffer + CL + deposits + finalize)
- `wstETH` value-accruing wrapper (1 wstETH = 1 share)
- On-chain oracle committee → `UnauthorizedOracle()`
- Positive / negative rebase (slashing)
- Request-ID `WithdrawalQueue` (`finalize` via finalizer = oracle at deploy)
- Immutable fee caps + Eth2 Deposit Contract (mock in lab)
- Slash fuzzing + solvency invariants
- `SWC-AUDIT-EN.md` + gas snapshot

Next.js frontend: **out of v1 scope**.
