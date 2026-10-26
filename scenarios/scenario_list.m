function S = scenario_list()
%SCENARIO_LIST  Fault scenarios run by run_all.m.
%
%   Mission phase start times (see config/mission_profile.m):
%     TAXI 0 s, TAKEOFF 360 s, CLIMB 480 s, CRUISE 960 s,
%     MISSION 1860 s, RTB 3960 s, APPROACH 4860 s, touchdown 5280 s.

ev0 = struct('t', {}, 'target', {}, 'action', {});

S = struct('name', {}, 'title', {}, 'events', {}, 'apu_start_fails', {}, 'batt_T', {}, 'expect_p1_powered', {});

S(end+1) = mk('S0_nominal', 'Nominal mission, no faults', ev0, false, 25, true);

S(end+1) = mk('S1_gen1_fail_apu_ok', 'GEN1 fails in the mission phase, APU starts', ...
    ev('GEN1', 2400), false, 25, true);

S(end+1) = mk('S2_gen1_fail_apu_fails', 'GEN1 fails in the mission phase, APU fails to start', ...
    ev('GEN1', 2400), true, 25, true);

S(end+1) = mk('S3_dual_gen_fail_apu_ok', 'Both generators fail, APU starts', ...
    [ev('GEN1', 2400), ev('GEN2', 2405)], false, 25, true);

S(end+1) = mk('S4_dual_gen_fail_battery_only', ...
    'Both generators fail 30 min before touchdown, APU fails, cold battery (-20 degC)', ...
    [ev('GEN1', 3480), ev('GEN2', 3480)], true, -20, true);

S(end+1) = mk('S5_dcdc_fault', 'DC/DC converter A fails in the mission phase', ...
    ev('DCDC1', 2400), false, 25, true);

S(end+1) = mk('S6_gen2_fail_takeoff', 'GEN2 fails during takeoff, APU starts', ...
    ev('GEN2', 420), false, 25, true);
end

function s = mk(name, title, events, apu_fails, T, expect)
s.name = name;
s.title = title;
s.events = events;
s.apu_start_fails = apu_fails;
s.batt_T = T;
s.expect_p1_powered = expect;
end

function e = ev(target, t)
e = struct('t', t, 'target', target, 'action', 'fail');
end
