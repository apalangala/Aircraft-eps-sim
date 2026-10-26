function bs = battery_init(b)
%BATTERY_INIT  Initial state of the battery pack model.
bs.soc = b.soc0;      % [-]
bs.v1  = 0;           % [V] cell RC-branch voltage
bs.i_cell = 0;        % [A] last cell current (+ = discharge)
bs.v_cell = battery_ocv(b, b.soc0);
bs.depleted = false;  % latched once the BMS cuts the pack off
bs.cut_reason = '';   % why it was cut off (see battery_step.m)
end
