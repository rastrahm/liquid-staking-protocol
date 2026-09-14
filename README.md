# 18 — Liquid Staking & Staking Derivatives

Protocolo de liquid staking estilo stETH/wstETH: shares rebasing, wrapper value-accruing, oracle de rewards/slashing, cola de withdrawal asíncrona y depósitos Eth2. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–5** ✅ · Fases **6–7** 🔒 pendientes de autorización.  
**Suite:** `forge test` → **75 PASS**.

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases, arquitectura, criterios de aceptación |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML de contratos |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Submit / oracle / queue |
| [`doc/flujograma.md`](./doc/flujograma.md) | Ciclo e2e |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Deps | forge-std **v1.16.2**, OpenZeppelin **v5.2.0** en `lib/` |
| Math | WAD `1e18` / RAY `1e27` (`ShareMath`) |
| EVM | Cancun (`evm_version = "cancun"`) |
| Seguridad | Custom errors, CEI, `.call{value}` (fases siguientes) |

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

## Deploy local (stub Fase 0)

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: copiar `.env.example` → `.env`.

## Alcance v1 (resumen)

- `stETH` (rebasing shares) + `wstETH` (wrapper)
- Oracle comité → `UnauthorizedOracle()`
- Rebase positivo / negativo (slashing)
- `WithdrawalQueue` request-ID
- Fee caps inmutables + Eth2 Deposit Contract (mock en tests)

Frontend Next.js: **fuera de v1**.

## Autorización de fases

Ver [`doc/planificacion.md`](./doc/planificacion.md). Responde `Autorizo Fase N` para continuar.
