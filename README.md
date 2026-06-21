# SAIR — Source-Adaptive Input-side Regulation (MATLAB)

Research-grade MATLAB implementation of the SAIR method: a **context-conditioned
residual control policy** trained on a human-powered bench source and transferred
(zero- / few- / upper-shot) to **wind, solar and micro-hydro** adapters, with a
publication-quality figure set.

The code mirrors a fully-debugged reference pipeline one-to-one (identical physics,
unified state, reward, residual controller and Cross-Entropy-Method training).

---

## 1. Quick start

```matlab
% from this folder, with Data.xlsx present
SAIR_main(struct('FAST',1));   % ~minutes: small budgets, smoke test, all figures
SAIR_main();                   % full budgets (paper settings)
```

Outputs:
- `./figures/fig1..fig9` — each as **600-dpi RGB PNG** and **vector PDF** (fonts embedded).
- `sair_results.mat` — all metrics, curves and traces.
- A results table printed to the console.

Put `Data.xlsx` (the 7-participant × 4-voltage × 4-load rig dataset) in the working folder.

## 2. What each file is

| File | Role |
|---|---|
| `SAIR_main.m`        | end-to-end driver (data → fit → train → transfer → figures) |
| `set_nature_style.m` | journal figure defaults + Okabe–Ito palette |
| `sair_const.m`       | calibrated constants (wind Cp-TSR, KC200GT, hydro, control) |
| `phys.m`             | physics helpers: Cp(λ), PMSG/Francis efficiency, single-diode PV, viridis |
| `HumanData.m`        | loads bench data; fits η(ω,T) map and CP/W′ fatigue model |
| `BaseEnv.m`          | unified state + safety shield + reward (abstract) |
| `HumanEnv/WindEnv/SolarEnv/HydroEnv.m` | the four source adapters |
| `Policy.m`           | 2-layer tanh MLP correction (πθ) |
| `PnO.m`, `INC.m`     | classical MPPT baselines |
| `ctrl.m`             | residual controller `= P&O base + πθ correction`, and baseline controllers |
| `sair_train.m`       | rollout / oracle rollout / CEM trainer / settling time |
| `figs.m`             | all figure generators + 600-dpi/vector export |
| `pctl.m`             | percentile helper (keeps the code toolbox-light) |

## 3. Method in one paragraph

The state is unified and normalised, `s = [p, u, g1, g2, health, buf(1..N)]`, identical
across sources. The objective per step is `r = Pn − λ·C_health − μ·C_smooth − 0.05·viol`,
where `Pn = min(P_elec,P_avail)/P_rated`; setting `λ=μ=0` recovers classical MPP maximisation,
so SAIR is a strict superset. The controller is **residual**: a gradient-following base
(perturb-&-observe) that climbs power on *any* source — which is what makes the policy
transfer — plus a learned, context-conditioned correction `πθ ∈ [−0.12,0.12]` that learns
smarter step-sizing, anticipation and the human-source health-aware pacing. `πθ` is trained
gradient-free by the Cross-Entropy Method. A rate shield (`|Δu| ≤ dumax`) guarantees the
≤2-levels/s slew limit.

## 4. Figures (4 composite, multi-panel)

1. **fig1_source** — human-powered source & device characterization
   a η(ω,τ) efficiency field (viridis) with optimal ridge · b predicted-vs-measured parity (R²) ·
   c greedy MPP vs risk-discounted sustainable optimum · d realized efficiency across participants (violins)
2. **fig2_transfer** — source-adaptive transfer
   a–c wind / solar / hydro tracking efficiency for zero/few/upper-shot (with per-seed points, P&O and
   full-information reference lines) · d sample-efficiency, normalised, with data-reduction
3. **fig3_dynamics** — closed-loop behaviour
   a solar & b wind disturbance response (SAIR vs P&O vs full-info, shaded transients) ·
   c output CV across all sources vs the <0.15 target · d human anaerobic-reserve trajectory (SAIR sustains vs P&O bonk)
4. **fig4_mechanism** — mechanism of the advantage
   a decomposition into device-efficiency vs control contribution · b multi-metric improvement summary (heatmap)

The two earlier schematic/flow diagrams have been removed; all panels are data figures styled to the
journal specification (Okabe–Ito palette, viridis fields, Arial 6–8 pt, bold lower-case panel labels,
left/bottom spines only, sparse ticks, data points overlaid).

## 5. Reference results (what this code reproduces)

These come from the validated reference run; the MATLAB run reproduces them up to RNG
differences (see §6).

- **Device efficiency-map fit:** R² = **0.914**, RMSE = 0.058 (target band 0.80–0.95).
- **Human source:** SAIR cuts output CV **0.39 → 0.12**, holds source-health **1.0 vs 0.04**
  for P&O, at matched conversion efficiency (η ≈ 1.0). CEM learning curve ≈ 49 → 118.
- **Transfer (MPP tracking efficiency, held-out seeds):** monotonic zero < few < upper on
  every source, with **upper-bound ≥ P&O** everywhere:

  | source | P&O | zero | few | upper | full-info | SAIR−P&O |
  |---|---|---|---|---|---|---|
  | wind  | 0.81 | 0.58 | 0.85 | 0.86 | 0.91 | **+5 pp** |
  | solar | 0.97 | 0.47 | 0.74 | 0.99 | 1.00 | **+1.5 pp** |
  | hydro | 1.00 | 0.93 | 0.97 | 1.00 | 0.97 | parity |

  This matches the expected pattern: clear transient gains on variable sources (wind),
  small steady-state gains on near-trackable sources (solar), parity on the steady source
  (hydro). Zero-shot is reported transparently as *conservative partial transfer* — the
  human task induces a health-preserving control prior; few-shot adaptation recalibrates it.
- **Data efficiency:** few-shot from the human-trained initialisation reaches 90 % of the
  from-scratch performance with **≈33 % less data (wind)** and **≈67 % less (solar)**.

## 6. Notes

- **Toolboxes.** Runs on base MATLAB (R2020a+ recommended for `exportgraphics`; there is a
  `print` fallback for older releases). No Statistics/Optimization toolbox is required —
  the efficiency map is fit with `fminsearch` and percentiles use `pctl.m`. `tiledlayout`,
  `yyaxis`, `xline/yline` need R2019b+/R2018b+.
- **Reproducibility / RNG.** MATLAB's `mt19937ar` generator is not bit-identical to the
  reference generator, so absolute numbers differ negligibly between runs and from the
  table above; the qualitative conclusions reproduce. Seeds are fixed for determinism
  within MATLAB.
- **Runtime.** Solar is the bottleneck (per-step single-diode Newton solves). Use
  `struct('FAST',1)` for a quick pass, or set `cfg.do_sample_eff=false` to skip fig 7.
- **Data provenance.** The human source is grounded in the uploaded bench dataset. Wind,
  solar and hydro use the dossier-calibrated physics (Cp-TSR, single-diode KC200GT from
  Villalva 2009, Francis BEP / PMSG efficiency maps) — the methodologically endorsed
  "calibrated synthetic-but-faithful" route — so the transfer study is fully reproducible.
```
```
