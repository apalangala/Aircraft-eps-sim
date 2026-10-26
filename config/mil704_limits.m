function lim = mil704_limits()
%MIL704_LIMITS  DC power-quality limits from MIL-STD-704F (12 March 2004).
%
%   Values transcribed from MIL-STD-704F Table IV (steady state) and
%   Figures 13 and 16 (normal transient envelopes). Envelope corner points
%   are joined by straight lines in time here; check against the figures in
%   the standard before using these for anything formal.

% 270 V DC
lim.hv.ss_min      = 250.0;   % [V] normal steady-state minimum
lim.hv.ss_max      = 280.0;   % [V] normal steady-state maximum
lim.hv.ripple_max  = 6.0;     % [V] ripple amplitude
% normal transient envelope, time measured from start of the transient
lim.hv.env_over_t  = [0     0.020 0.040 1e9];
lim.hv.env_over_v  = [330   330   280   280];
lim.hv.env_under_t = [0     0.010 0.040 1e9];
lim.hv.env_under_v = [200   200   250   250];

% 28 V DC
lim.lv.ss_min      = 22.0;
lim.lv.ss_max      = 29.0;
lim.lv.ripple_max  = 1.5;
lim.lv.env_over_t  = [0     0.0125 0.0825 1e9];
lim.lv.env_over_v  = [50    50     29     29];
lim.lv.env_under_t = [0     0.015  0.100  1e9];
lim.lv.env_under_v = [18    18     22     22];

% Bus / source transfer: voltage may sit between zero and the normal
% limits for no longer than this (MIL-STD-704F para 5.1)
lim.transfer_interrupt_max = 0.050;   % [s]
end
