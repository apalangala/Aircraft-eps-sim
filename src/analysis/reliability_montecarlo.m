function r = reliability_montecarlo(rp, T, scale, n, seed)
%RELIABILITY_MONTECARLO  Time-resolved Monte Carlo of losing the essential bus.
%
%   r = RELIABILITY_MONTECARLO(rp, T, scale, n, seed)
%
%   Draws exponential failure times for every component and replays the
%   bus manager's logic in time: the APU is commanded when the first
%   generator is lost and comes online 45 s later if it starts; the
%   battery carries HVE whenever no main source path exists. The essential
%   bus is lost if the busbar faults, or if at any moment there is no main
%   path AND no battery path. Unlike the fault tree this respects event
%   order (e.g. an APU that fails before it is needed does not matter
%   until it is needed). Rates are multiplied by scale.

if nargin < 5, seed = 1; end
rng(seed);
ex = @(lam) -log(rand(n, 1)) / (lam * scale);

t_g1 = ex(rp.lambda_gen);
t_g2 = ex(rp.lambda_gen);
t_ccf = ex(rp.beta_ccf * rp.lambda_gen);
t_both = min(max(t_g1, t_g2), t_ccf);         % both generators gone
t_first = min(min(t_g1, t_g2), t_ccf);        % first generator gone -> APU start
start_ok = rand(n, 1) >= rp.p_apu_start;
t_apu_on = t_first + rp.apu_start_time_h;
t_apu_on(~start_ok) = inf;
t_apu_off = t_apu_on + ex(rp.lambda_apu);     % running failure after start
t_efc = max(ex(rp.lambda_efc), ex(rp.lambda_efc));
t_b = min(ex(rp.lambda_batt), ex(rp.lambda_bcru));
t_hve = ex(rp.lambda_hve);

% intervals during which there is no main-source path to HVE
% (1) both essential feeds failed: [t_efc, inf)
% (2) both generators gone and APU not running:
%     [t_both, t_apu_on) and [max(t_both, t_apu_off), inf)
hit = t_hve < T;
hit = hit | overlaps(t_efc, inf(n, 1), t_b, T);
a = t_both; b = min(t_apu_on, inf);
gap = b > a;                                  % APU not yet online when gens are gone
hit = hit | (gap & overlaps(a, b, t_b, T));
hit = hit | overlaps(max(t_both, t_apu_off), inf(n, 1), t_b, T);

r.n = n;
r.scale = scale;
r.n_hits = sum(hit);
r.P_mission = r.n_hits / n;
r.ci95 = 1.96 * sqrt(r.P_mission * (1 - r.P_mission) / n);
end

function o = overlaps(a, b, t_b, T)
% interval [a, b) intersects [t_b, T]
lo = max(a, t_b);
hi = min(b, T);
o = lo < hi;
end
