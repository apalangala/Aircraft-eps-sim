function test_energy_balance()
%TEST_ENERGY_BALANCE  Power in = power out at every step:
%   sources (incl. BCRU output) = served loads + DC/DC and inverter losses + battery charging.
R = short_runs();
for k = 1:numel(R)
    lg = R(k).out.log;
    lhs = sum(lg.P_src, 1);
    rhs = sum(lg.P_served, 1) + lg.loss + lg.P_charge;
    err = max(abs(lhs - rhs));
    assert(err < 1e-6 * max(1, max(lhs)), sprintf('%s: power imbalance %.3g W', R(k).name, err));
    % battery terminal power = BCRU output + BCRU loss when discharging
    dis = lg.P_src(4, :) > 0 & lg.P_batt > 0;
    e2 = max(abs(lg.P_batt(dis) - lg.P_src(4, dis) - lg.loss_bcru(dis)));
    if ~isempty(e2)
        assert(e2 < 1e-6, sprintf('%s: battery/BCRU imbalance %.3g W', R(k).name, e2));
    end
end
end
