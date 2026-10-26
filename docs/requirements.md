# Requirements and traceability

Each requirement below is checked by at least one automated test in `tests/`. Run `run_all_tests` to check them all. The test report is written to `results/test_report.txt`.

The requirements are written for this study's generic aircraft. They follow the style of a real system specification, so every one is specific and testable.

## Bus management

| ID | Requirement | Verified by |
|---|---|---|
| REQ-BM-01 | Two power sources (generators, APU, battery converter) shall never be connected in parallel on the same bus. | `test_bus_logic_truth_table` (all 16 source-health combinations), `test_no_paralleling_in_sim` (every time step of every fault run) |
| REQ-BM-02 | A failed source shall never be connected to a bus. | `test_bus_logic_truth_table` |
| REQ-BM-03 | At most one essential-bus feed (EFC1 or EFC2) shall be closed at any time. | `test_bus_logic_truth_table` |
| REQ-BM-04 | The essential bus HVE shall be powered whenever any source, including the battery, is available. | `test_bus_logic_truth_table` |
| REQ-BM-05 | If any generator or the APU is available, both main 270 V buses shall be powered, and the battery shall not discharge. | `test_bus_logic_truth_table` |
| REQ-BM-06 | Loss of a generator shall command an APU start. The APU shall take load only once it is online, 45 s after the command. | `test_apu_sequencing` |

## Load management

| ID | Requirement | Verified by |
|---|---|---|
| REQ-LM-01 | Flight-critical (priority 1) loads shall never be shed. They shall stay powered through any failure that leaves at least one source, including battery-only operation to touchdown. | `test_p1_loads_never_unpowered` |
| REQ-LM-02 | No source shall run above its continuous rating for longer than the shed delay (0.5 s). | `test_shedding_order_and_hysteresis` |
| REQ-LM-03 | On a given source, no priority-2 load shall be shed while a priority-3 load on that source is still on. | `test_shedding_order_and_hysteresis` |
| REQ-LM-04 | Loads shall not chatter. No load is shed more than 3 times in a fault run. | `test_shedding_order_and_hysteresis` |

## Power quality (MIL-STD-704F)

| ID | Requirement | Verified by |
|---|---|---|
| REQ-PQ-01 | Every powered bus shall stay inside the normal steady-state band: 250 to 280 V on 270 V buses, 22 to 29 V on the 28 V bus. | `test_mil704_steady_state` |
| REQ-PQ-02 | A load application of 25 % to 100 % of generator rating, and the matching load rejection, shall stay inside the normal transient envelope (Figure 16). | `test_transient_envelope` |
| REQ-PQ-03 | A bus transfer shall interrupt power for no more than 50 ms. The recovery shall then stay inside the normal transient envelope. | `test_transient_envelope` (passes only with the soft start) |
| REQ-PQ-04 | Bus ripple caused by the pulsed radar shall not exceed 6 V. | `study_pulsed_radar` sizes the buffer that achieves this |

## Battery and stability

| ID | Requirement | Verified by |
|---|---|---|
| REQ-BAT-01 | The battery alone shall carry the flight-critical loads for 30 min, covering 8 min of mission, 15 min of return and a 7 min approach and landing. This shall hold new and at end of life, at 25 °C and at −20 °C. | `test_battery_endurance_requirement` (study profile plus full system simulation of scenario S4) |
| REQ-STAB-01 | The radar power supply shall be small-signal stable on the 270 V bus from 0 to 80 kW. | `test_stability` |

## Model checks

These are not system requirements. They test that the model itself is right.

| Check | Test |
|---|---|
| Power in equals power out (sources = loads + losses + charging) at every step | `test_energy_balance` |
| Battery model: coulomb counting, RC branch settling, temperature direction, cut-off latch; converter efficiency at rated power | `test_battery_model` |
| Envelope checker catches a known violation and accepts a known pass | `test_transient_envelope` |
| Linear model agrees with the textbook LC-filter limit and with time-domain simulation | `test_stability` |
| Monte Carlo agrees with the fault tree where event order cannot matter, and stays below it where the tree is conservative | `test_reliability` |
| Radar headroom thresholds are ordered as the architecture requires | `test_radar_headroom` |
