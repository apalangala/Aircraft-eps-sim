function test_battery_endurance_requirement()
%TEST_BATTERY_ENDURANCE_REQUIREMENT  REQ-BAT-01: the configured pack carries
%   the flight-critical loads for 30 min on battery alone at all four
%   corners (new / end of life, 25 / -20 degC), and one string fewer does not
%   (i.e. the configured size is the minimum the sizing study found).
p = eps_params();
L = load_table();
m = mission_profile();
prof = emergency_load_profile(p, L, m, {'MISSION', 'RTB', 'APPROACH'}, [8 15 7]);
corners = [25 1 1; -20 1 1; 25 0.8 1.5; -20 0.8 1.5];
worst_fails_smaller = false;
for c = 1:size(corners, 1)
    b = p.batt;
    b.T_degC = corners(c, 1); b.age_Q = corners(c, 2); b.age_R = corners(c, 3);
    r = simulate_battery_profile(b, prof, 1);
    assert(r.survived, sprintf('Battery cut off at %.1f min (%s) at corner %d', r.t_cut / 60, r.reason, c));
    b.Np = b.Np - 1;
    r2 = simulate_battery_profile(b, prof, 1);
    worst_fails_smaller = worst_fails_smaller || ~r2.survived;
end
assert(worst_fails_smaller, 'Configured Np is larger than needed; rerun study_battery_sizing');

% full simulator: dual generator failure + APU failure, cold battery, to touchdown
R = short_runs();
out = R(strcmp({R.name}, 'dual_gen_fail_battery_only')).out;
assert(~out.batt_depleted, 'Battery ran out before touchdown in the system simulation');
assert(out.summary.batt_emergency_s >= p.req.emergency_endurance_min * 60 - 1, ...
    'Battery-only period shorter than expected');
end
