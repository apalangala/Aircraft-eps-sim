function R = short_runs()
%SHORT_RUNS  Shortened fault scenarios shared by several tests (cached).
%
%   Each run starts at the beginning of the MISSION phase (1860 s), puts
%   the fault in at 1900 s and stops 6 minutes later, so the whole test
%   suite stays quick. S4 starts just before its fault and runs to
%   touchdown, because its requirement is about reaching the ground.
persistent cache
if ~isempty(cache)
    R = cache;
    return
end
ev = @(target, t) struct('t', t, 'target', target, 'action', 'fail');
none = struct('t', {}, 'target', {}, 'action', {});
S = struct('name', {}, 'events', {}, 'apu_start_fails', {}, 'batt_T', {}, 't_start', {}, 't_end', {});
S(end+1) = mk('nominal', none, false, 25, 1860, 2260);
S(end+1) = mk('gen1_fail_apu_ok', ev('GEN1', 1900), false, 25, 1860, 2260);
S(end+1) = mk('gen2_fail_apu_fails', ev('GEN2', 1900), true, 25, 1860, 2260);
S(end+1) = mk('dual_gen_fail_apu_ok', [ev('GEN1', 1900), ev('GEN2', 1905)], false, 25, 1860, 2260);
S(end+1) = mk('dcdc_fault', ev('DCDC1', 1900), false, 25, 1860, 2260);
S(end+1) = mk('dual_gen_fail_battery_only', [ev('GEN1', 3480), ev('GEN2', 3480)], true, -20, 3460, 5280);
R = struct('name', {}, 'out', {});
for k = 1:numel(S)
    sc = S(k);
    sc.title = sc.name;
    R(k).name = sc.name;
    R(k).out = run_system_sim(sc);
end
cache = R;
end

function s = mk(name, events, apu_fails, T, t0, t1)
s.name = name;
s.events = events;
s.apu_start_fails = apu_fails;
s.batt_T = T;
s.t_start = t0;
s.t_end = t1;
end
