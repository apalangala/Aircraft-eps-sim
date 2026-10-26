function test_battery_model()
%TEST_BATTERY_MODEL  Checks on the equivalent-circuit battery model.
b = eps_params().batt;

% OCV table is monotonic and inside the cell's voltage window
assert(all(diff(b.ocv_tab) > 0), 'OCV table not monotonic');
assert(b.ocv_tab(1) >= b.v_cell_min && b.ocv_tab(end) <= 4.2 + 1e-9, 'OCV outside cell limits');

% Coulomb counting: constant power discharge, SOC drop = integral of current / capacity
bs = battery_init(b);
dt = 1; Iint = 0; soc0 = bs.soc;
for k = 1:600
    [bs, P] = battery_step(b, bs, 10e3, dt);
    assert(P == 10e3, 'Pack refused a modest discharge');
    Iint = Iint + bs.i_cell * dt;
end
[~, ~, Q] = battery_cell_params(b);
expect = Iint / (3600 * Q);
assert(abs((soc0 - bs.soc) - expect) < 1e-9, 'SOC does not follow coulomb counting');

% Terminal power check: pack power = Ns*Np * i * v_cell
assert(abs(b.Ns * b.Np * bs.i_cell * bs.v_cell - 10e3) < 1e-6, 'Pack power inconsistent with cell model');

% RC branch settles to R1 * i under constant current (after >> tau)
[~, R1] = battery_cell_params(b);
assert(abs(bs.v1 - R1 * bs.i_cell) / (R1 * bs.i_cell) < 0.01, 'RC branch did not settle to R1*i');

% Charging raises SOC
soc1 = bs.soc;
for k = 1:60
    bs = battery_step(b, bs, -2e3, dt);
end
assert(bs.soc > soc1, 'Charging did not raise SOC');

% Cold battery has less capacity and more resistance
bc = b; bc.T_degC = -20;
[R0c, ~, Qc] = battery_cell_params(bc);
[R0w, ~, Qw] = battery_cell_params(b);
assert(R0c > R0w && Qc < Qw, 'Temperature correction has the wrong direction');

% BMS cut-off latches and reports why
bs = battery_init(b);
bs.soc = b.soc_min;
[bs, P] = battery_step(b, bs, 5e3, dt);
assert(P == 0 && bs.depleted && strcmp(bs.cut_reason, 'energy'), 'Cut-off at minimum SOC not applied');
[bs, P] = battery_step(b, bs, 1e3, dt);
assert(P == 0, 'Cut-off did not latch');

% Converter loss model: efficiency at rated power equals eta_rated
loss = conv_loss(6.5e3, 6.5e3, 0.93, 0.2, true);
assert(abs(6.5e3 / (6.5e3 + loss) - 0.93) < 1e-12, 'Converter efficiency at rated power wrong');
assert(conv_loss(1e3, 6.5e3, 0.93, 0.2, false) == 0, 'De-energised converter has losses');
end
