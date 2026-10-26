function test_shedding_order_and_hysteresis()
%TEST_SHEDDING_ORDER_AND_HYSTERESIS  REQ-LM-02..04.
%   (1) Sources never stay above continuous rating for longer than the
%       shed delay (fault runs).
%   (2) Shedding order: with one generator carrying everything, every
%       priority-3 load on that generator is shed before any priority-2
%       load, and priority-1 loads are never shed (direct unit test of
%       the load manager).
%   (3) No chattering: at most 3 shed events per load per run.
p = eps_params();
L = load_table();
info = load_info(L);
m = mission_profile();
prio = info.prio;

% ---- (1) and (3) on the fault runs --------------------------------------
R = short_runs();
for k = 1:numel(R)
    lg = R(k).out.log;
    for s = 1:3
        over = lg.P_src(s, :) > lg.cap(s, :) + 1;
        run_len = max_run(over) * p.dt;
        assert(run_len <= p.shed.delay + p.dt + 1e-9, ...
            sprintf('%s: source %d over rating for %.2f s', R(k).name, s, run_len));
    end
    ns = R(k).out.lm.n_shed_events;
    assert(all(ns <= 3), sprintf('%s: a load was shed %d times (chattering)', R(k).name, max(ns)));
end

% ---- (2) unit test of the shedding order --------------------------------
h.gen_ok = [false true]; h.apu_ok = false; h.batt_ok = true;
h.dcdc_ok = [true true]; h.inv_ok = true;
bm = bus_manager(h);
caps.GEN1 = struct('cont', 0, 'ovl', 0);
caps.GEN2 = struct('cont', p.gen(2).P_rated, 'ovl', p.gen(2).ovl_factor * p.gen(2).P_rated);
caps.APU = struct('cont', 0, 'ovl', 0);
caps.BATT = struct('cont', p.bcru.P_rated, 'ovl', p.bcru.P_rated);
ph = find(strcmp(m.names, 'MISSION'));
P_full = info.D(:, ph)';
lm = load_manager_init(L);
p3_loads = find(prio == 3 & P_full > 0);
any_shed = false;
for step = 1:20
    lm = load_manager_step(p, L, lm, P_full, bm, h, caps, 0, p.dt, info);
    shed_now = lm.lvl > 1;
    any_shed = any_shed || any(shed_now);
    assert(~any(shed_now & prio == 1), 'A priority-1 load was shed');
    % checked after every step: no priority-2 load reduced while a
    % priority-3 load on this generator is still on
    if any(shed_now & prio == 2)
        assert(all(shed_now(p3_loads)), 'A priority-2 load was shed before all priority-3 loads');
    end
end
assert(any_shed, 'Expected shedding with one generator in the mission phase');
% after shedding, the generator is within its continuous rating
pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), 0, info);
assert(pf.P_src(2) <= p.gen(2).P_rated, 'Generator still over rating after shedding');
end

function n = max_run(x)
n = 0; c = 0;
for i = 1:numel(x)
    if x(i), c = c + 1; n = max(n, c); else, c = 0; end
end
end
