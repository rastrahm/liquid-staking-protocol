# 18 — Liquid Staking & Staking Derivatives

Protocolo de liquid staking estilo stETH/wstETH: shares rebasing, wrapper value-accruing, oracle de rewards/slashing, cola de withdrawal asíncrona y depósitos Eth2. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).  
**Suite:** `forge test` → **90 PASS**.

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/README.md`](./doc/README.md) | Índice de documentación |
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases, arquitectura, criterios |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Submit / oracle / queue |
| [`doc/flujograma.md`](./doc/flujograma.md) | Ciclo e2e |
| [`doc/SWC-AUDIT.md`](./doc/SWC-AUDIT.md) | Matriz SWC-100–136 |
| [`doc/GAS.md`](./doc/GAS.md) | Optimizaciones + snapshot |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std **v1.16.2**, OpenZeppelin **v5.2.0** en `lib/` |
| Math | WAD `1e18` / RAY `1e27` (`ShareMath` + OZ `mulDiv`) |
| Guard | `ReentrancyGuardTransient` (Cancun) |
| EVM | Cancun (`via_ir = true`) |

## Setup Foundry

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copiar `.env.example` → `.env`.

## Gas

```bash
forge test --match-contract LiquidStakingGasTest --gas-report
forge snapshot --match-contract LiquidStakingGasTest
```

## Alcance v1

- `StETH` = pool unificado (rebasing shares + buffer + CL + deposits + finalize)
- `wstETH` wrapper value-accruing (1 wstETH = 1 share)
- Oracle comité on-chain → `UnauthorizedOracle()`
- Rebase positivo / negativo (slashing)
- `WithdrawalQueue` request-ID (`finalize` vía finalizer = oracle en deploy)
- Fee caps inmutables + Eth2 Deposit Contract (mock en lab)
- Fuzz slash + invariantes de solvencia
- `SWC-AUDIT.md` + gas snapshot

Frontend Next.js: **fuera de v1**.
