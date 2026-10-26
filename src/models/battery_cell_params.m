function [R0, R1, Q_Ah] = battery_cell_params(b)
%BATTERY_CELL_PARAMS  Cell R0, R1 [ohm] and usable capacity [Ah] after
%   temperature and ageing corrections (table clamps outside -20..45 degC).
Rm = interp_lin(b.T_tab, b.Rmult_tab, b.T_degC);
Qm = interp_lin(b.T_tab, b.Qmult_tab, b.T_degC);
R0 = b.R0 * Rm * b.age_R;
R1 = b.R1 * Rm * b.age_R;
Q_Ah = b.Q_cell * Qm * b.age_Q;
end
