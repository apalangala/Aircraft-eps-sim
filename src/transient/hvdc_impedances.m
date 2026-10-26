function [Zout, Zin] = hvdc_impedances(tp, G_load, P_cpl, f)
%HVDC_IMPEDANCES  Middlebrook source / load impedances at frequencies f [Hz].
%
%   Zout - output impedance of the source side seen from the radar-PSU
%          filter input: generator + regulator + bus capacitance + resistive load.
%   Zin  - input impedance of the radar PSU: LC filter (+ damping branch)
%          feeding a constant-power load, whose incremental resistance is
%          -V^2/P (negative: more voltage -> less current).
%
%   Middlebrook criterion: if |Zout| << |Zin| at every frequency (6 dB of
%   separation is the usual design target) the converter-on-bus system is
%   stable. Where they overlap, stability has to be checked another way.

x0 = hvdc_equilibrium(tp, G_load, P_cpl);
v = x0(2); v_cf = x0(4);
w = 2 * pi * f(:)';
s = 1i * w;

% --- source side: states [i_s v x_pi E], current injected into the bus ---
%  L_s di = E - R_s i - v ; C dv = i - G v + i_inj ; dx_pi = -Ki v ; tau dE = -Kp v + x_pi - E
%  (small-signal: the fed-forward set-point is constant)
A = [-tp.R_s/tp.L_s, -1/tp.L_s,            0,          1/tp.L_s;
      1/tp.C_dc,     -G_load/tp.C_dc,      0,          0;
      0,             -tp.Ki,               0,          0;
      0,             -tp.Kp/tp.tau_ex,     1/tp.tau_ex, -1/tp.tau_ex];
B = [0; 1/tp.C_dc; 0; 0];
Cm = [0 1 0 0];
Zout = zeros(size(s));
for k = 1:numel(s)
    Zout(k) = Cm * ((s(k) * eye(4) - A) \ B);
end

% --- load side: filter + damping + CPL ----------------------------------
R_cpl = -v_cf^2 / max(P_cpl, 1e-9);
Y = s * tp.C_f + 1 / R_cpl;
if tp.damp
    Y = Y + 1 ./ (tp.R_d + 1 ./ (s * tp.C_d));
end
Zin = tp.R_f + s * tp.L_f + 1 ./ Y;
%#ok<*NASGU>
end
