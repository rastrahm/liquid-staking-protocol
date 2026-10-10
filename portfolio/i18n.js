const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Liquid Staking & Derivatives — Rolando Strahm',
    'meta.description':
      'Liquid staking estilo stETH/wstETH: shares rebasing, oracle CL/EL, withdrawal queue, Eth2 deposits. Gas · SWC-100–136. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 18 · PORTFOLIO WEB3',
    'hero.title': 'LIQUID STAKING<br>&amp; DERIVATIVES',
    'hero.role': 'Solidity 0.8.24 · Foundry · stETH · wstETH · Oracle · SWC',
    'hero.sub':
      'Protocolo de liquid staking estilo stETH/wstETH: shares rebasing, wrapper value-accruing, oracle CL/EL, cola de withdrawal asíncrona y depósitos Eth2. Gas documentado + matriz SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Construí un <strong>pool unificado en StETH</strong> estilo Lido: <strong>shares rebasing</strong>, wrapper <strong>wstETH</strong> (1 wstETH = 1 share), <strong>AccountingOracle</strong> con comité on-chain, <strong>WithdrawalQueue</strong> request → finalize → claim, y <strong>depositBufferedEther</strong> al Eth2 Deposit Contract. El foco es <strong>UnauthorizedOracle</strong>, <strong>negative rebase</strong> sin soft-lock, <strong>fee caps</strong> inmutables y <strong>SWC</strong> con fuzz + invariantes de solvencia.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Dual-token LST',
    'p1.desc':
      'Submit ETH → mint shares; wrap/unwrap wstETH; oracle rebase +/−; queue asíncrona y deposits 32 ETH.',
    'p1.l1': 'UnauthorizedOracle + ReportTooEarly',
    'p1.l2': 'NegativeRebaseBlocked + fee caps 10%',
    'p1.l3': 'CEI + ReentrancyGuardTransient (Cancun)',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Transient tstore, OZ mulDiv, fees immutables, custom errors, CEI en claim y maxDeposits en keeper.',
    'p2.l1': 'submit ~41 691 gas (snapshot)',
    'p2.l2': 'withdrawal lifecycle ~222 232',
    'p2.l3': '.gas-snapshot + optimizer 10k · via_ir',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, OracleReport, WithdrawalQueue, SlashingResilience fuzz, PoolSolvency invariantes.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '31 mitigados / N/A · 5 info',
    'p3.l3': '90 tests Foundry PASS',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 7: baseline en <code>doc/GAS.md</code> y <code>.gas-snapshot</code>. Paths: <strong>submit 41 691</strong>, <strong>wrap 111 534</strong>, <strong>oracle rebase 151 952</strong>, <strong>withdrawal lifecycle 222 232</strong>, <strong>deposit 1 validador 493 067</strong>.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'ReentrancyGuardTransient (tstore)',
    'gas.r1b': 'Sin SSTORE del guard OZ; requiere Cancun',
    'gas.r2a': 'OZ Math.mulDiv (512-bit)',
    'gas.r2b': 'Overflow-safe sin FullMath propio',
    'gas.r3a': 'Fee recipients / bps immutables',
    'gas.r3b': 'SLOAD barato; caps en constructor',
    'gas.r4a': 'Custom errors (LiquidStakingErrors)',
    'gas.r4b': 'Reverts compactos vs require strings',
    'gas.r5a': 'CEI + .call{value} único',
    'gas.r5b': 'claim / finalizeWithdrawals sin estado roto',
    'gas.r6a': 'maxDeposits en keeper path',
    'gas.r6b': 'Acota gas del loop de validadores',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining hot paths; OK sin Poseidon asm',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre StETH, WstETH, AccountingOracle, WithdrawalQueue, FeeDistributor y ShareMath. Informe: <code>doc/SWC-AUDIT.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1. Tests: OracleReport · WithdrawalQueue · SlashingResilience · PoolSolvency.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; OZ mulDiv; checks antes de restas buffer/shares',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'Unchecked return: .call{value} chequea ok → EthTransferFailed',
    'swc.r107': 'Reentrancy: TransientGuard + CEI en claim/finalize',
    'swc.r105': 'ETH out solo claim owner+finalized o depósitos Eth2',
    'swc.r115': 'Auth: Ownable2Step, oracle membership, finalizer; no tx.origin',
    'swc.r123': 'Requirements: LiquidStakingErrors + matriz Fase 7',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Front-running approve / queue',
    'swc.i1d':
      'Allowance ERC-20 puede frontrunearse. Claim owner fijado; finalize compite por liquidez de buffer (permissioned).',
    'swc.i2t': 'Comité sin EIP-712',
    'swc.i2d':
      'v1 auth por membership on-chain (msg.sender). Sin quorum multi-firma; trust en comité. Post-v1: EIP-712.',
    'swc.i3t': 'depositDataRoot de lab',
    'swc.i3d':
      'Root keccak de conveniencia + MockDepositContract. Mainnet requiere root Eth2 canónico SSZ.',
    'swc.i4t': 'Liquidez vs CL',
    'swc.i4d':
      'Finalize exige buffer líquido. ETH en validadores no está disponible hasta retornos EL/CL (asíncrono por diseño).',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'TDD por gates: ShareMath/StETH, WstETH, oracle+fees, deposits Eth2, WithdrawalQueue, fuzz slash + invariantes, gas+Deploy+SWC.',
    'ph.01': 'Setup Foundry + ShareMath · StETH',
    'ph.23': 'WstETH + Oracle rebase +/− · fees',
    'ph.45': 'NodeOps · DepositContract · WithdrawalQueue',
    'ph.6': 'Fuzz slash · PoolSolvency invariants',
    'ph.7': 'Gas · Deploy · SWC · docs',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerables',
    'st.4': 'Fee cap',
    'term.label': 'rolando@strahm:~/18-liquid-staking-protocol',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 90 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 5 · Mitigados/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_18_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'UnauthorizedOracle, negative rebase, misuse de cola, FeeCapExceeded y fuzz slash: el “éxito” del misuse es que revierte. Sin PoCs de exploit.',
    'cA.t': 'Oracle unauthorized',
    'cA.d': 'Reporter no miembro / no oracle → UnauthorizedOracle.',
    'cB.t': 'Negative rebase',
    'cB.d': 'Slash / CL baja: rate ↓; pooled=0 con shares → NegativeRebaseBlocked.',
    'cC.t': 'Queue misuse',
    'cC.d': 'NotFinalized / AlreadyClaimed / NotOwner → revert (CEI + EthTransferFailed).',
    'cD.t': 'Fee cap',
    'cD.d': 'protocolFeeBps &gt; 1000 en deploy → FeeCapExceeded.',
    'cE.t': 'Fuzz + invariant',
    'cE.d': 'SlashingResilience ≥ 1000 runs; PoolSolvency no soft-lock.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: StETH/wstETH, oracle, queue, tests, GAS.md, SWC-AUDIT.md, diagramas y Deploy.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Liquid Staking & Derivatives · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · stETH · wstETH · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Liquid Staking & Derivatives — Rolando Strahm',
    'meta.description':
      'stETH/wstETH-style liquid staking: rebasing shares, CL/EL oracle, withdrawal queue, Eth2 deposits. Gas · SWC-100–136. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 18 · WEB3 PORTFOLIO',
    'hero.title': 'LIQUID STAKING<br>&amp; DERIVATIVES',
    'hero.role': 'Solidity 0.8.24 · Foundry · stETH · wstETH · Oracle · SWC',
    'hero.sub':
      'stETH/wstETH-style liquid staking: rebasing shares, value-accruing wrapper, CL/EL oracle, async withdrawal queue, and Eth2 deposits. Documented gas + SWC-100–136 matrix.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'I built a Lido-style <strong>unified StETH pool</strong>: <strong>rebasing shares</strong>, <strong>wstETH</strong> wrapper (1 wstETH = 1 share), on-chain committee <strong>AccountingOracle</strong>, <strong>WithdrawalQueue</strong> request → finalize → claim, and <strong>depositBufferedEther</strong> to the Eth2 Deposit Contract. Focus: <strong>UnauthorizedOracle</strong>, <strong>negative rebase</strong> without soft-lock, immutable <strong>fee caps</strong>, and <strong>SWC</strong> with fuzz + solvency invariants.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module delivers',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Dual-token LST',
    'p1.desc':
      'Submit ETH → mint shares; wrap/unwrap wstETH; oracle rebase +/−; async queue and 32 ETH deposits.',
    'p1.l1': 'UnauthorizedOracle + ReportTooEarly',
    'p1.l2': 'NegativeRebaseBlocked + 10% fee caps',
    'p1.l3': 'CEI + ReentrancyGuardTransient (Cancun)',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Transient tstore, OZ mulDiv, immutable fees, custom errors, CEI on claim, maxDeposits on keeper.',
    'p2.l1': 'submit ~41 691 gas (snapshot)',
    'p2.l2': 'withdrawal lifecycle ~222 232',
    'p2.l3': '.gas-snapshot + optimizer 10k · via_ir',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, OracleReport, WithdrawalQueue, SlashingResilience fuzz, PoolSolvency invariants.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '31 mitigated / N/A · 5 info',
    'p3.l3': '90 Foundry tests PASS',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 7: baseline in <code>doc/GAS.md</code> and <code>.gas-snapshot</code>. Paths: <strong>submit 41 691</strong>, <strong>wrap 111 534</strong>, <strong>oracle rebase 151 952</strong>, <strong>withdrawal lifecycle 222 232</strong>, <strong>1-validator deposit 493 067</strong>.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'ReentrancyGuardTransient (tstore)',
    'gas.r1b': 'No OZ guard SSTORE; requires Cancun',
    'gas.r2a': 'OZ Math.mulDiv (512-bit)',
    'gas.r2b': 'Overflow-safe without custom FullMath',
    'gas.r3a': 'Immutable fee recipients / bps',
    'gas.r3b': 'Cheap SLOAD; caps at constructor',
    'gas.r4a': 'Custom errors (LiquidStakingErrors)',
    'gas.r4b': 'Compact reverts vs require strings',
    'gas.r5a': 'CEI + single .call{value}',
    'gas.r5b': 'claim / finalizeWithdrawals without broken state',
    'gas.r6a': 'maxDeposits on keeper path',
    'gas.r6b': 'Bounds gas of the validator deposit loop',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Hot-path inlining; fine without Poseidon asm',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      '<strong>SWC-100 → SWC-136</strong> matrix over StETH, WstETH, AccountingOracle, WithdrawalQueue, FeeDistributor, and ShareMath. Report: <code>doc/SWC-AUDIT.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope. Tests: OracleReport · WithdrawalQueue · SlashingResilience · PoolSolvency.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; OZ mulDiv; checks before buffer/shares subtracts',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'Unchecked return: .call{value} checks ok → EthTransferFailed',
    'swc.r107': 'Reentrancy: TransientGuard + CEI on claim/finalize',
    'swc.r105': 'ETH out only via owner+finalized claim or Eth2 deposits',
    'swc.r115': 'Auth: Ownable2Step, oracle membership, finalizer; no tx.origin',
    'swc.r123': 'Requirements: LiquidStakingErrors + Phase 7 matrix',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Approve / queue front-running',
    'swc.i1d':
      'ERC-20 allowance can be front-run. Claim owner is fixed; finalize competes for buffer liquidity (permissioned).',
    'swc.i2t': 'Committee without EIP-712',
    'swc.i2d':
      'v1 auth via on-chain membership (msg.sender). No multi-sig quorum; committee trust. Post-v1: EIP-712.',
    'swc.i3t': 'Lab depositDataRoot',
    'swc.i3d':
      'Convenience keccak root + MockDepositContract. Mainnet needs canonical Eth2 SSZ root.',
    'swc.i4t': 'Liquidity vs CL',
    'swc.i4d':
      'Finalize needs liquid buffer. ETH in validators is unavailable until EL/CL returns (async by design).',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'TDD by gates: ShareMath/StETH, WstETH, oracle+fees, Eth2 deposits, WithdrawalQueue, slash fuzz + invariants, gas+Deploy+SWC.',
    'ph.01': 'Foundry setup + ShareMath · StETH',
    'ph.23': 'WstETH + Oracle rebase +/− · fees',
    'ph.45': 'NodeOps · DepositContract · WithdrawalQueue',
    'ph.6': 'Slash fuzz · PoolSolvency invariants',
    'ph.7': 'Gas · Deploy · SWC · docs',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerable',
    'st.4': 'Fee cap',
    'term.label': 'rolando@strahm:~/18-liquid-staking-protocol',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 90 passed · 0 failed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 5 · Mitigated/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_18_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'UnauthorizedOracle, negative rebase, queue misuse, FeeCapExceeded, and slash fuzz: misuse “success” means revert. No exploit PoCs.',
    'cA.t': 'Unauthorized oracle',
    'cA.d': 'Non-member / non-oracle reporter → UnauthorizedOracle.',
    'cB.t': 'Negative rebase',
    'cB.d': 'Slash / lower CL: rate ↓; pooled=0 with shares → NegativeRebaseBlocked.',
    'cC.t': 'Queue misuse',
    'cC.d': 'NotFinalized / AlreadyClaimed / NotOwner → revert (CEI + EthTransferFailed).',
    'cD.t': 'Fee cap',
    'cD.d': 'protocolFeeBps &gt; 1000 at deploy → FeeCapExceeded.',
    'cE.t': 'Fuzz + invariant',
    'cE.d': 'SlashingResilience ≥ 1000 runs; PoolSolvency no soft-lock.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same code on GitHub and GitLab: StETH/wstETH, oracle, queue, tests, GAS.md, SWC-AUDIT.md, diagrams, and Deploy.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Liquid Staking & Derivatives · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · stETH · wstETH · ALL_SYSTEMS_OPERATIONAL',
  },
};

(function () {
  const STORAGE_KEY = 'portfolio-lang';
  const params = new URLSearchParams(window.location.search);
  let lang = params.get('lang') || localStorage.getItem(STORAGE_KEY) || 'es';
  if (!I18N[lang]) lang = 'es';

  function apply(langCode) {
    const dict = I18N[langCode] || I18N.es;
    document.documentElement.lang = dict['html.lang'] || langCode;

    const title = document.querySelector('title');
    if (title && dict['meta.title']) title.textContent = dict['meta.title'];

    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc && dict['meta.description']) metaDesc.setAttribute('content', dict['meta.description']);

    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      const val = dict[key];
      if (val == null) return;
      if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
      else el.textContent = val;
    });

    document.querySelectorAll('.lang-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.getAttribute('data-lang') === langCode);
    });

    localStorage.setItem(STORAGE_KEY, langCode);
  }

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => apply(btn.getAttribute('data-lang')));
  });

  apply(lang);
})();
