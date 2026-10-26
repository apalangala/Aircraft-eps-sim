function tp = transient_params()
%TRANSIENT_PARAMS  Parameters of the averaged (event-level) 270 V DC bus model.
%
%   One 270 V DC channel: a generator + rectifier modelled as a controlled
%   EMF E behind R_s and L_s, a voltage regulator (PI) acting through an
%   exciter lag, the main-bus capacitance, a resistive load, and a
%   constant-power load (a converter-fed radar power supply) behind its
%   own LC input filter, with an optional R-C damping branch.
%
%   "Averaged" means switching ripple inside converters is not modelled:
%   the model is good for 0.1 ms to seconds, which is the range the
%   MIL-STD-704 transient envelopes cover. Values are assumptions chosen to
%   be representative; see docs/assumptions.md.

tp.Vref = 270;            % [V] regulator set-point

% generator + rectifier (60 kW channel)
tp.R_s  = 0.03;           % [ohm] equivalent source resistance (~2.5 % drop at rated current)
tp.L_s  = 100e-6;         % [H]   equivalent commutating inductance
tp.tau_ex = 0.010;        % [s]   exciter / field time constant
tp.Kp   = 1.5;            % [-]   regulator proportional gain
tp.Ki   = 150;            % [1/s] regulator integral gain
tp.E_max = 400;           % [V]   EMF ceiling (field forcing limit)
tp.E_min = 0;             % [V]
tp.I_lim = 2.5 * 60e3 / 270;  % [A] generator control unit current limit (~2.5 per unit)

% main bus
tp.C_dc = 2e-3;           % [F] bus capacitance (rectifier output + distributed)

% radar power supply input filter (feeds the constant-power load)
tp.L_f  = 20e-6;          % [H]
tp.C_f  = 470e-6;         % [F]
tp.R_f  = 0.009;          % [ohm] inductor DCR + capacitor ESR
tp.damp = false;          % R-C damping branch across C_f fitted?
tp.R_d  = 0.2;            % [ohm] damping resistor   (~sqrt(L_f/C_f))
tp.C_d  = 4 * 470e-6;     % [F]   damping capacitor  (4 x C_f, Middlebrook / Erickson rule of thumb)

% constant-power load behaviour at low voltage: below this the converter
% stops regulating power (undervoltage lockout) and looks resistive
tp.V_uvlo = 0.5 * 270;    % [V]

% integration
tp.dt = 20e-6;            % [s] fixed RK4 step (~30 steps per period of the 1.6 kHz filter resonance)
end
