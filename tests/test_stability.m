function test_stability()
%TEST_STABILITY  REQ-STAB-01: the radar power supply with its damped input
%   filter is small-signal stable up to 80 kW; without damping it is
%   unstable at its 25 kW operating point (documented finding). Also
%   cross-checks the linear model against the textbook LC + CPL limit and
%   against time-domain simulation.
tp = transient_params();
G = 20e3 / tp.Vref^2;

tp.damp = true;
for P = [10e3 25e3 50e3 80e3]
    e = eig(linearize_hvdc(tp, G, P));
    assert(all(real(e) < 0), sprintf('Damped system unstable at %.0f kW', P / 1e3));
end

tp.damp = false;
e = eig(linearize_hvdc(tp, G, 25e3));
assert(any(real(e) > 0), 'Undamped filter expected unstable at 25 kW');
e = eig(linearize_hvdc(tp, G, 10e3));
assert(all(real(e) < 0), 'Undamped filter expected stable at 10 kW');

% critical power sits above the ideal-source estimate R_f*C_f*V^2/L_f
% (source resistance adds a little damping) but below 25 kW
r = study_stability(transient_params(), '');
assert(r.P_crit_undamped_W > r.P_crit_simple_W && r.P_crit_undamped_W < 25e3, ...
    'Critical power outside the expected range');
% time domain agrees with the eigenvalues
assert(r.undamped_osc_pp_V > 50, 'Undamped time-domain run did not oscillate');
assert(r.damped_osc_pp_V < 1, 'Damped time-domain run did not settle');
end
