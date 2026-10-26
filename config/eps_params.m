function p = eps_params()
%EPS_PARAMS  Baseline parameters for the aircraft electrical power system.
%
%   p = EPS_PARAMS() returns a struct with every number the system-level
%   simulator uses. Every value is an engineering assumption for a GENERIC
%   twin-engine military UAV / light combat aircraft. None of them describe a
%   real aircraft. Where a value comes from a standard or is a typical
%   order of magnitude, the comment says so. See docs/assumptions.md for the
%   reasoning behind each group.

% -------------------------------------------------------------------------
% Simulation
% -------------------------------------------------------------------------
p.dt = 0.25;                 % [s] system-level time step (power-flow model)

% -------------------------------------------------------------------------
% Nominal voltages (MIL-STD-704F, Table IV)
% -------------------------------------------------------------------------
p.V_hv = 270;                % [V] high-voltage DC bus nominal
p.V_lv = 28;                 % [V] low-voltage DC bus nominal

% -------------------------------------------------------------------------
% Main generators: engine-driven starter-generator + rectifier, 270 V DC out
% -------------------------------------------------------------------------
gen.P_rated   = 60e3;        % [W] continuous rating (assumption)
gen.ovl_factor = 1.5;        % [-] short-time overload capability (typical 150 %)
gen.tau_th    = 300;         % [s] thermal time constant of the overload model
gen.th_max    = 1.2;         % [-] thermal limit; above it only the continuous
                             %     rating is available (see generator_step.m)
p.gen = [gen, gen];
p.gen(1).name = 'GEN1';
p.gen(2).name = 'GEN2';

% -------------------------------------------------------------------------
% APU generator
% -------------------------------------------------------------------------
p.apu.name       = 'APU';
p.apu.P_rated    = 40e3;     % [W] continuous rating (assumption)
p.apu.ovl_factor = 1.25;     % [-]
p.apu.tau_th     = 300;      % [s]
p.apu.th_max     = 1.2;      % [-]
p.apu.start_time = 45;       % [s] in-flight start to generator online (assumption)

% -------------------------------------------------------------------------
% Battery: Li-ion NMC pack on the essential bus via a bidirectional
% DC/DC converter (BCRU). Cell values are representative of a generic
% high-power 18650-format NMC cell, not a specific datasheet.
% -------------------------------------------------------------------------
b.Ns        = 74;            % [-] series cells -> 74 x 3.65 V = 270 V nominal
b.Np        = 31;            % [-] parallel strings, from studies/study_battery_sizing.m (EOL, -20 degC case)
b.Q_cell    = 2.5;           % [Ah] cell capacity at 25 degC, beginning of life
b.R0        = 0.020;         % [ohm] cell series resistance at 25 degC
b.R1        = 0.015;         % [ohm] cell RC-branch resistance at 25 degC
b.C1        = 2000;          % [F]   cell RC-branch capacitance (tau = 30 s)
b.m_cell    = 0.045;         % [kg]  cell mass
b.pack_mass_factor = 1.4;    % [-]   pack mass / cell mass (housing, BMS, cooling)
b.soc_tab   = 0:0.1:1;       % OCV-SOC table (typical NMC shape)
b.ocv_tab   = [3.00 3.45 3.55 3.62 3.68 3.74 3.82 3.90 3.98 4.07 4.18];
b.T_tab     = [-20 0 25 45]; % [degC] temperature table
b.Rmult_tab = [3.0 1.8 1.0 0.85];   % resistance multiplier vs temperature
b.Qmult_tab = [0.80 0.90 1.0 1.0];  % usable-capacity multiplier vs temperature
b.T_degC    = 25;            % [degC] battery temperature (scenario can override)
b.age_Q     = 1.0;           % [-] capacity fraction (1.0 = new, 0.8 = end of life)
b.age_R     = 1.0;           % [-] resistance growth (1.0 = new, 1.5 = end of life)
b.soc0      = 0.90;          % [-] initial state of charge
b.soc_min   = 0.05;          % [-] BMS cut-off state of charge
b.v_cell_min = 3.0;          % [V] BMS cut-off cell voltage under load
b.i_cell_max = 20;           % [A] max continuous cell discharge current
b.soc_target = 0.90;         % [-] charge controller target
b.P_charge_max = 3e3;        % [W] max charge power drawn from the bus
p.batt = b;

p.bcru.name    = 'BCRU';
p.bcru.P_rated = 30e3;       % [W] battery converter rating
p.bcru.eta     = 0.95;       % [-] efficiency at rated power

% -------------------------------------------------------------------------
% Power converters
% -------------------------------------------------------------------------
dc.P_rated = 6.5e3;          % [W] each 270 V -> 28 V DC/DC converter (2 in parallel)
dc.eta     = 0.93;           % [-] efficiency at rated power
p.dcdc = [dc, dc];
p.dcdc(1).name = 'DCDC-A';
p.dcdc(2).name = 'DCDC-B';

p.inv.name    = 'INV';       % 270 V DC -> 115 V AC 400 Hz inverter
p.inv.P_rated = 8e3;         % [W]
p.inv.eta     = 0.92;        % [-]

p.conv_noload_frac = 0.2;    % [-] share of rated-power loss that is fixed (no-load)

% -------------------------------------------------------------------------
% Distribution (steady-state voltage drop)
% -------------------------------------------------------------------------
p.R_feeder_hv = 0.020;       % [ohm] generator feeder resistance to main bus
p.R_feeder_ess = 0.010;      % [ohm] main bus -> essential bus feeder
p.R_droop_lv  = 0.0013;      % [ohm] DC/DC output droop (per converter share)
p.R_droop_bcru = 0.005;      % [ohm] BCRU output droop

% -------------------------------------------------------------------------
% Load management
% -------------------------------------------------------------------------
p.shed.margin        = 0.95; % [-] shed down to this fraction of continuous rating
p.shed.delay         = 0.5;  % [s] overload must persist this long before shedding
p.shed.restore_delay = 5.0;  % [s] headroom must persist this long before restoring
p.shed.restore_frac  = 0.10; % [-] restore hysteresis, fraction of the load step
p.shed.restore_abs   = 500;  % [W] restore hysteresis, absolute
p.shed.battery_essential_only = true; % on battery, keep only priority-1 loads

% -------------------------------------------------------------------------
% Requirements used by checks and tests
% -------------------------------------------------------------------------
p.req.emergency_endurance_min = 30;   % [min] battery-only endurance requirement
p.req.mil704 = mil704_limits();
end
