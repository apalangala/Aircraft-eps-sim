function P_max = battery_power_limit(b, bs)
%BATTERY_POWER_LIMIT  Max discharge power [W] the pack can deliver right now
%   without hitting the cell current limit or the cut-off voltage.
if bs.depleted
    P_max = 0;
    return
end
[R0, ~, ~] = battery_cell_params(b);
e = battery_ocv(b, bs.soc) - bs.v1;
i_v = max((e - b.v_cell_min) / R0, 0);    % current that pulls v down to v_min
i_lim = min(b.i_cell_max, i_v);
P_cell = i_lim * (e - i_lim * R0);
P_max = max(P_cell, 0) * b.Ns * b.Np;
end
