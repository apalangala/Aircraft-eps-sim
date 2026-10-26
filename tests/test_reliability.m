function test_reliability()
%TEST_RELIABILITY  The Monte Carlo and the fault tree agree where they must.
%   - Check case (no APU running failures, instant start): event order
%     cannot matter, so the two must agree within the 95 % interval.
%   - Full model: the fault tree is conservative, so the Monte Carlo must
%     not exceed it (beyond sampling noise).
%   - The analytic result is reproduced by hand for the dominant term.
rp = reliability_params();
m = mission_profile();
T = m.T_total / 3600;
scale = 1000; n = 1e6;

rc = rp; rc.lambda_apu = 0; rc.apu_start_time_h = 0;
ft = reliability_fault_tree(rc, T, scale);
mc = reliability_montecarlo(rc, T, scale, n, 11);
assert(abs(mc.P_mission - ft.P_mission) <= 1.2 * mc.ci95, ...
    sprintf('Check case: MC %.3g vs FT %.3g (CI %.2g)', mc.P_mission, ft.P_mission, mc.ci95));

ft = reliability_fault_tree(rp, T, scale);
mc = reliability_montecarlo(rp, T, scale, n, 12);
assert(mc.P_mission <= ft.P_mission + mc.ci95, 'Monte Carlo above the conservative fault tree');

ft1 = reliability_fault_tree(rp, T);
assert(abs(ft1.contrib.hve_fault - (1 - exp(-rp.lambda_hve * T)) / T) < 1e-15, 'Busbar term wrong');
assert(ft1.P_split_per_fh < ft1.P_per_fh, 'Split bus should reduce the risk');
end
