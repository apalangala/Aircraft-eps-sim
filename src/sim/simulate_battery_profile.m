function r = simulate_battery_profile(b, prof, dt, t_max)
%SIMULATE_BATTERY_PROFILE  Discharge the pack through a piecewise-constant
%   power profile and report whether (and why) it is cut off.
%
%   r = SIMULATE_BATTERY_PROFILE(b, prof, dt) runs the profile once.
%   r = SIMULATE_BATTERY_PROFILE(b, prof, dt, t_max) repeats the LAST
%   segment until cut-off or t_max [s] (used for endurance).
%
%   r.survived   true if the pack carried the whole profile
%   r.t_cut      time of cut-off [s] (NaN if none)
%   r.reason     'energy' | 'voltage' | 'current' | 'power' | ''
%   r.soc_end, r.v_cell_min, and time histories r.t, r.soc, r.v_cell

if nargin < 3 || isempty(dt), dt = 1; end
T_prof = sum(prof.dur_s);
if nargin < 4 || isempty(t_max), t_max = T_prof; end
N = round(t_max / dt);
edges = cumsum(prof.dur_s);

bs = battery_init(b);
r.t = (1:N) * dt;
r.soc = NaN(1, N);
r.v_cell = NaN(1, N);
r.t_cut = NaN;
r.reason = '';
for i = 1:N
    t = (i - 1) * dt;
    seg = find(t < edges, 1, 'first');
    if isempty(seg), seg = numel(edges); end
    [bs, P_act] = battery_step(b, bs, prof.P_batt(seg), dt);
    r.soc(i) = bs.soc;
    r.v_cell(i) = bs.v_cell;
    if bs.depleted && P_act == 0
        r.t_cut = t;
        r.reason = bs.cut_reason;
        break
    end
end
r.survived = isnan(r.t_cut) || r.t_cut >= T_prof;
r.soc_end = bs.soc;
r.v_cell_min = min(r.v_cell);
end
