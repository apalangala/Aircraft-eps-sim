# Assumptions

Everything in this model describes a **generic twin-engine military UAV**, invented for this study. No number belongs to a real aircraft. Where a value comes from a standard or is a common rule of thumb, this page says so. Every number lives in one place in `config/`, so changing an assumption means changing one line.

## Architecture

- **270 V DC primary distribution.** This is the "more-electric aircraft" approach: high-voltage DC cuts cable mass compared with 115 V AC. A 28 V DC bus serves avionics, and a small 115 V 400 Hz AC bus serves legacy AC equipment.
- **Two engine-driven generators, one per main bus,** with a bus tie through a central tie bus. The APU generator connects to the tie bus.
- **Generators are never paralleled.** DC generators can share load in parallel, but doing so needs load-sharing control and makes fault isolation harder. Many architectures avoid it, and this one does too.
- **The essential bus HVE carries all flight-critical 270 V loads.** It is fed from HV1, else from HV2, else from the battery.
- **The battery sits behind a bidirectional DC/DC converter (BCRU).** The BCRU is always connected. It charges from spare capacity and switches to discharge without a break when both main buses are lost. In the bus-logic graph this is drawn as a contactor (BLC) that "closes" when the BCRU is in discharge mode.

## Sources (`config/eps_params.m`)

| Item | Value | Basis |
|---|---|---|
| Generator continuous rating | 60 kW each | Sized so two generators carry the 71 kW mission load at about 60 % loading |
| Generator overload | 150 %, thermal model with τ = 300 s | Typical short-time rating for aircraft generators |
| APU generator | 40 kW, 45 s in-flight start | Assumption |
| Feeder resistance | 20 mΩ generator to main bus, 10 mΩ main to essential | Gives about 1.5 % voltage drop at full load |

## Battery

| Item | Value | Basis |
|---|---|---|
| Cell | Generic high-power 18650 NMC, 2.5 Ah, R0 = 20 mΩ, one RC branch (15 mΩ, τ = 30 s), 45 g | Representative values, not one datasheet |
| OCV curve | 3.00 V at 0 % to 4.18 V at 100 %, typical NMC shape | Representative |
| Temperature | Resistance ×3.0 and capacity ×0.8 at −20 °C | Typical Li-ion behaviour at low temperature |
| End of life | 80 % capacity, 1.5× resistance | Common end-of-life definition |
| BMS cut-off | SOC < 5 %, loaded cell voltage < 3.0 V, or cell current > 20 A | Typical |
| Pack mass | Cell mass × 1.4 | Housing, BMS, cooling and wiring |
| Series cells | 74 (270 V nominal) | 74 × 3.65 V |
| Parallel strings | **31**, set by `study_battery_sizing` | Smallest that meets REQ-BAT-01 at all four corners |

## Converters

The loss model is P_loss = P0 + k·P². It is fitted so efficiency at rated power matches the value below, and 20 % of the rated-power loss is fixed (no-load) loss.

| Converter | Rating | Efficiency at rating |
|---|---|---|
| DC/DC 270 V to 28 V (×2, equal sharing) | 6.5 kW each | 93 % |
| Inverter 270 V DC to 115 V AC 400 Hz | 8 kW | 92 % |
| BCRU (battery converter) | 30 kW | 95 % |

## Loads (`config/load_table.m`)

There are 14 loads in three priority classes. Demand is set per mission phase.

- **Priority 1, flight-critical, never shed:** flight control actuators, fuel pumps, landing gear and brakes, flight computers, the C2 datalink, and engine control. The C2 datalink counts as flight-critical because a UAV is flown through it.
- **Priority 2, mission:** AESA radar, ECS / liquid cooling, mission SATCOM, and the EO/IR turret. The radar can drop to a 50 % mode before it is switched off.
- **Priority 3, non-essential:** ice protection, bay heaters, the payload bay, and lighting.

In the mission phase, cooling follows the radar: **ECS = 8 kW + 0.4 × radar power**. Radar waste heat has to be removed, so more radar power means more cooling power.

**Shed order:** P3 loads are shed first (payload, heaters, lighting, ice protection), then EO/IR, SATCOM, the radar (50 %, then off), and finally ECS. Restoration runs in reverse priority order. A shed load only comes back when it fits with a 10 % + 500 W margin for 5 s.

## Mission (`config/mission_profile.m`)

| Phase | Taxi | Takeoff | Climb | Cruise | Mission | Return (RTB) | Approach and landing |
|---|---|---|---|---|---|---|---|
| Duration | 6 min | 2 min | 8 min | 15 min | 35 min | 15 min | 7 min |

The total is 88 min.

## Transient model (`config/transient_params.m`)

This is an averaged model of one 270 V channel. The generator and rectifier are a controlled EMF behind 30 mΩ and 100 µH. A PI voltage regulator acts through a 10 ms exciter lag. Bus capacitance is 2 mF and the generator current limit is 2.5 per unit.

The radar power supply is a constant-power load behind a 20 µH / 470 µF / 9 mΩ input filter. Its optional damping branch is 0.2 Ω in series with 4 × C_f, a standard rule of thumb for damping an LC filter.

"Averaged" means switching inside converters is not modelled. The model is valid from about 0.1 ms to seconds, which is the range the MIL-STD-704 envelopes cover.

## Reliability (`config/reliability_params.m`)

Failure rates are **illustrative orders of magnitude**, not qualified data:

| Item | Value |
|---|---|
| Generator channel | 1e-4 per flight hour |
| Common-cause fraction, both generators | 2 % |
| APU in-flight start failure | 5 % |
| APU running failure | 5e-4 per flight hour |
| Battery | 2e-5 per flight hour |
| BCRU | 3e-5 per flight hour |
| Essential feed contactor path | 5e-6 per flight hour each |
| Essential busbar fault | 1e-7 per flight hour |

The target of 1e-9 per flight hour for a catastrophic failure condition comes from civil certification guidance (CS-25.1309 / AC 25.1309-1). It is used here as a yardstick only.

## Standards used

- **MIL-STD-704F** (12 March 2004), *Aircraft Electric Power Characteristics*:
  - Table IV steady-state limits.
  - Figure 13 (28 V) and Figure 16 (270 V) normal transient envelopes.
  - Para 5.1, the 50 ms limit on power interruption during a transfer.

  Envelope corner points are joined by straight lines in time. Check them against the figures before any formal use.
