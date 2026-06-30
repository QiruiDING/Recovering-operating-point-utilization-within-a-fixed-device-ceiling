# Durability-Aware Recovery of Operating-Point Utilization

Code and reproducibility package for:

> **Durability-aware recovery of operating-point utilization: a hardware-calibrated closed-loop human-generator model with model-based transfer to renewable harvesters**

This repository implements **SAIR** (Source-Adaptive Input-side Regulation), a durability-aware residual controller for energy harvesters operating under time-varying source conditions.

SAIR combines:

- a perturb-and-observe (P&O) base controller;
- a context-conditioned learned residual correction;
- source-specific adapters and safety constraints;
- a durability-aware reward;
- gradient-free training using the cross-entropy method (CEM);
- few-shot transfer through encoder recalibration.

The study evaluates SAIR on:

1. a hardware-calibrated closed-loop human-powered electricity-generation model;
2. calibrated wind, photovoltaic, and micro-hydro conversion models;
3. photovoltaic and wind hardware-in-the-loop (HIL) emulator testbeds.

---

## Scope and evidence boundary

This repository accompanies a research study. Its evidence should be interpreted as follows:

- **Human-powered generation:** evaluated in a closed-loop digital plant calibrated using bench measurements from an instrumented bicycle-generator platform.
- **Wind, solar, and micro-hydro:** evaluated using calibrated physics-based conversion models and disturbance trajectories.
- **Hardware-in-the-loop validation:** conducted on real power electronics using a photovoltaic emulator and a motor-driven wind-turbine emulator.
- **Field deployment:** not claimed in this study.

SAIR is not a zero-shot universal controller. The human-trained policy requires **target-domain encoder recalibration** before achieving competitive performance on a new renewable source.

---

## Main idea

The realized electrical output of an energy-harvesting system is represented as

\[
P_{\mathrm{elec}} =
\eta_{\mathrm{nom}}
\cdot
\chi_{\mathrm{op}}
\cdot
\eta_{\mathrm{down}}
\cdot
P_{\mathrm{src}},
\]

where:

- \(\eta_{\mathrm{nom}}\) is the device-level conversion ceiling;
- \(\chi_{\mathrm{op}}\) is operating-point utilization determined by control;
- \(\eta_{\mathrm{down}}\) represents downstream drivetrain or power-electronics efficiency;
- \(P_{\mathrm{src}}\) is the available source power.

The controller cannot improve the intrinsic device ceiling. Its role is to recover the portion of output lost because the operating point is mismatched, delayed during transients, or unsustainably operated.

For the human-powered source, SAIR additionally protects a finite anaerobic reserve using a critical-power / work-capacity model.

---

## SAIR controller

At each time step, SAIR combines a classical P&O action with a bounded learned correction:

\[
u_t =
\Pi_{\mathrm{shield}}
\left(
u_t^{\mathrm{base}} + \Delta u_t
\right),
\]

where:

- \(u_t^{\mathrm{base}}\) is the P&O control action;
- \(\Delta u_t\) is the learned residual correction;
- \(\Pi_{\mathrm{shield}}\) enforces actuator range, slew-rate, and source-protection limits.

The controller state includes normalized output power, prior control action, first- and second-order power differences, a source-protection margin, and a recent power-history window.

The reward is

\[
r_t =
\frac{P_{\mathrm{elec},t}}{P_{\mathrm{rated}}}
-
\lambda C_{\mathrm{dur},t}
-
\mu
\left(
\frac{u_t-u_{t-1}}{\Delta u_{\max}}
\right)^2
-
\kappa \mathbb{1}[\mathrm{shield\ active}].
\]

The shared correction network is transferred across sources. During few-shot commissioning, the correction weights remain frozen and only the context encoder is recalibrated.

---

## Sources and source-specific adapters

SAIR uses one shared correction policy, but each source still requires a lightweight physical adapter.

| Source | Control input | Device-level utilization | Protection margin |
|---|---|---|---|
| Human generator | Electromagnetic resistance | Generator-efficiency ridge utilization | Anaerobic reserve |
| Wind turbine | Reaction torque | Power-coefficient utilization | Structural-load margin |
| Photovoltaic array | Converter duty cycle | MPP utilization | Thermal margin |
| Micro-hydro turbine | Guide-vane opening / electrical load | Best-efficiency-point utilization | Cavitation / off-BEP margin |

SAIR does **not** require an online calibrated predictive model at every control step. However, practical deployment still requires source-specific normalization, actuator limits, operating-point mapping, and safety constraints.

---

## Experimental platforms

### Human-powered electricity generation

The human-source environment was calibrated from an instrumented rim-drive bicycle-generator platform.

- Participants: 7 adult volunteers
- Conversion trials: 112
- Battery-bank voltages: 12, 24, 36, and 48 V
- Electrical loads: 10, 30, 50, and 70 W
- Mechanical-power measurement: dual-pedal strain gauges and Hall-effect cadence sensing
- Electrical-power measurement: synchronized multi-channel analyzer
- Generator-map held-out fit: \(R^2 = 0.918\), RMSE = 0.059

The human environment uses a participant-specific critical-power and anaerobic-work-capacity model.

### Renewable-source models

The renewable transfer study includes:

- wind-turbine models driven by SCADA-derived turbulence conditions;
- photovoltaic models based on a five-parameter single-diode array model;
- micro-hydro models with best-efficiency-point tracking and off-BEP penalties.

The renewable models are used for model-based transfer evaluation and do not represent field deployment results.

---

## Main results

### Human-generator closed-loop model

| Controller | Output CV | Final reserve | Delivered energy |
|---|---:|---:|---:|
| Tuned P&O | 0.39 | 0.04 | 37.1 kJ |
| Static critical-power cap | 0.28 | 0.96 | 36.0 kJ |
| SAIR | 0.10 | 0.97 | 38.0 kJ |

SAIR reduces output-power variability while preserving the anaerobic reserve at matched delivered energy. The static critical-power cap protects the reserve but produces more variable output and lower delivered energy.

### Renewable-source transfer

| Source | Tuned P&O | SAIR zero-shot | SAIR few-shot | SAIR from scratch |
|---|---:|---:|---:|---:|
| Wind | 0.840 | 0.690 | 0.878 | 0.882 |
| Solar | 0.970 | 0.790 | 0.980 | 0.984 |
| Micro-hydro | 0.985 | 0.920 | 0.988 | 0.989 |

Values are MPP-tracking efficiencies.

Zero-shot transfer underperforms on all three renewable sources. After encoder recalibration, few-shot SAIR reaches close to from-scratch performance while requiring substantially less target-domain commissioning data.

### Hardware-in-the-loop validation

| Testbed | Controller | Tracking efficiency | Output CV |
|---|---|---:|---:|
| PV emulator | Tuned P&O | 0.948 | 0.480 |
| PV emulator | SAIR | 0.962 | 0.460 |
| PV emulator | Full-information reference | 0.971 | 0.450 |
| Wind emulator | Tuned P&O | 0.831 | 0.680 |
| Wind emulator | SAIR | 0.870 | 0.645 |

For the PV emulator, SAIR improved tracking efficiency by 1.4 percentage points over tuned P&O across 20 paired runs. For the wind emulator, SAIR achieved a 3.9-percentage-point transient gain, consistent with the model-based estimate.

---

## Controller configuration

| Component | Setting |
|---|---|
| Base controller | Perturb-and-observe |
| Correction network | Two-layer tanh MLP, hidden width = 32 |
| Context window | 20 steps |
| Context dimension | 8 |
| Residual correction bound | ±0.12 normalized input units |
| Slew limit | 2 actuator levels/s |
| Durability weight \(\lambda\) | 0.30 |
| Smoothness weight \(\mu\) | 0.10 |
| Shield penalty \(\kappa\) | 0.05 |
| Human-source CEM training | 40 iterations, population = 100, elite fraction = 0.10 |
| Few-shot CEM recalibration | 10 iterations, population = 20, elite fraction = 0.20 |

The main shared configuration is set on the human source and held fixed across the renewable transfer experiments. Only the P&O perturbation step varies by source.

---

## Repository structure

```text
.
├── configs/
│   ├── human/
│   ├── wind/
│   ├── solar/
│   ├── hydro/
│   └── hil/
├── data/
│   ├── processed/
│   ├── disturbance_seeds/
│   └── metadata/
├── sair/
│   ├── adapters/
│   ├── controllers/
│   ├── environments/
│   ├── models/
│   ├── training/
│   ├── evaluation/
│   └── visualization/
├── scripts/
│   ├── train_human.py
│   ├── transfer_few_shot.py
│   ├── evaluate_baselines.py
│   ├── reproduce_figures.py
│   └── reproduce_tables.py
├── results/
├── requirements.txt
├── environment.yml
└── README.md
