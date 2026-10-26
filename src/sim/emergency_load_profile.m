function prof = emergency_load_profile(p, L, m, phases, minutes)
%EMERGENCY_LOAD_PROFILE  Battery terminal power on battery-only operation.
%
%   prof = EMERGENCY_LOAD_PROFILE(p, L, m, phases, minutes) returns, for each
%   listed mission phase, the power the battery must deliver when it alone
%   carries the essential bus: priority-1 loads at full power, everything
%   else shed (p.shed.battery_essential_only), DC/DC and BCRU losses included.
%
%   phases  - cell array of phase names, e.g. {'MISSION','RTB','APPROACH'}
%   minutes - time spent in each [min]
%
%   prof.P_batt [W] per segment, prof.dur_s [s] per segment.

h.gen_ok = [false false]; h.apu_ok = false; h.batt_ok = true;
h.dcdc_ok = [true true]; h.inv_ok = true;
bm = bus_manager(h);
info = load_info(L);
frac = double(info.prio == 1);
prof.phases = phases;
prof.dur_s = minutes * 60;
prof.P_batt = zeros(1, numel(phases));
prof.P_bus = zeros(1, numel(phases));
for k = 1:numel(phases)
    ph = find(strcmp(m.names, phases{k}), 1);
    pf = power_flow(p, L, bm, h, info.D(:, ph)', frac, 0, info);
    prof.P_batt(k) = pf.P_batt;
    prof.P_bus(k) = pf.P_src(4);
end
end
