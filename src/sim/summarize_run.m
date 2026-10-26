function s = summarize_run(out)
%SUMMARIZE_RUN  Key numbers from one scenario run.
lg = out.log;
L = out.L;
p = out.p;
dt = p.dt;
prio = [L.prio];

p1 = prio == 1;
p1_dead = any(lg.status(p1, :) < 1 & lg.P_full(p1, :) > 0, 1);
s.p1_unpowered_s = sum(p1_dead) * dt;

shed_any = lg.status >= 0 & lg.status < 2 & lg.P_full > 0;
s.shed_time_s = sum(shed_any, 2)' * dt;            % per load
s.energy_not_served_kWh = sum(lg.P_full - lg.P_served, 2)' * dt / 3.6e6;
s.n_shed_events = out.lm.n_shed_events;
s.n_restore_events = out.lm.n_restore_events;

s.max_sources_per_island = max(lg.sources_per_island);
s.gens_ever_paralleled = any(lg.paralleled_gens);
s.any_deficit = any(lg.deficit);

s.soc_min = min(lg.soc);
s.soc_end = lg.soc(end);
s.batt_depleted = out.batt_depleted;
emerg = lg.mode == find(strcmp(out.modes, 'BATTERY_EMERGENCY'));
s.batt_emergency_s = sum(emerg) * dt;
if any(emerg)
    t0 = lg.t(find(emerg, 1, 'first'));
    if out.batt_depleted
        t1 = lg.t(find(emerg, 1, 'last')) + dt;
        s.batt_endurance_min = (t1 - t0) / 60;
    else
        s.batt_endurance_min = NaN;   % never ran out
    end
    s.batt_emergency_start_s = t0;
else
    s.batt_endurance_min = NaN;
    s.batt_emergency_start_s = NaN;
end

lim = p.req.mil704;
names = {'HV1', 'HV2', 'HVE', 'LV'};
for b = 1:4
    v = lg.V(b, :);
    live = v > 1;
    if any(live)
        s.Vmin.(names{b}) = min(v(live));
        s.Vmax.(names{b}) = max(v(live));
    else
        s.Vmin.(names{b}) = NaN;
        s.Vmax.(names{b}) = NaN;
    end
end
s.hv_ss_ok = all([s.Vmin.HV1 s.Vmin.HV2 s.Vmin.HVE] >= lim.hv.ss_min | isnan([s.Vmin.HV1 s.Vmin.HV2 s.Vmin.HVE])) && ...
             all([s.Vmax.HV1 s.Vmax.HV2 s.Vmax.HVE] <= lim.hv.ss_max | isnan([s.Vmax.HV1 s.Vmax.HV2 s.Vmax.HVE]));
s.lv_ss_ok = (isnan(s.Vmin.LV) || s.Vmin.LV >= lim.lv.ss_min) && (isnan(s.Vmax.LV) || s.Vmax.LV <= lim.lv.ss_max);

s.apu_start_cmd_t = out.apu_start_cmd_t;
s.apu_online_t = out.apu_online_t;
s.peak_P_src_kW = max(lg.P_src, [], 2)' / 1e3;
s.gen_energy_kWh = sum(sum(lg.P_src(1:3, :))) * dt / 3.6e6;   % electrical energy from generators
end
