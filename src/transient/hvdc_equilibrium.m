function x0 = hvdc_equilibrium(tp, G_load, P_cpl)
%HVDC_EQUILIBRIUM  Steady operating point of the averaged 270 V DC channel.
v = tp.Vref;                                   % integral action -> zero error
disc = v^2 - 4 * tp.R_f * P_cpl;
if disc < 0
    error('hvdc_equilibrium:noSolution', 'No DC operating point for P = %.0f W', P_cpl);
end
v_cf = (v + sqrt(disc)) / 2;
i_f = P_cpl / v_cf;
i_s = G_load * v + i_f;
E = v + tp.R_s * i_s;
x0 = [i_s; v; i_f; v_cf; E - v; E; v_cf];      % x_pi = E - Vref at steady state
end
