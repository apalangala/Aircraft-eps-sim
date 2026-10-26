function r = reliability_fault_tree(rp, T, scale)
%RELIABILITY_FAULT_TREE  Analytic probability of losing the essential bus.
%
%   r = RELIABILITY_FAULT_TREE(rp, T) for a mission of T flight hours.
%   r = RELIABILITY_FAULT_TREE(rp, T, scale) multiplies every failure rate
%   (not the APU start probability) by scale; used to validate the Monte
%   Carlo model at rates high enough to see failures.
%
%   Top event: no power on the essential bus HVE at some point in the mission.
%
%     TOP  = HVE_FAULT  OR  ( NO_MAIN  AND  NO_BATT )
%     NO_MAIN = ( BOTH_GENS AND APU_UNAVAIL )  OR  ( EFC1 AND EFC2 )
%     BOTH_GENS = ( GEN1 AND GEN2 ) OR GEN_CCF
%     APU_UNAVAIL = START_FAIL OR APU_FAILS_RUNNING
%     NO_BATT = BATT OR BCRU
%
%   Assumes non-repairable components in flight, independence apart from
%   the beta-factor common cause, and a battery sized to reach landing
%   (studies/study_battery_sizing.m). Events are treated as static over the
%   mission, which is slightly conservative for the APU running term.
%
%   Also returns the result for a split essential bus (two buses, each
%   able to carry the flight-critical loads, each with its own battery
%   path), where losing one busbar is no longer catastrophic. A beta-factor
%   rp.beta_bus covers faults that take out both halves together (shared
%   wiring zone, common software); r.split_beta_max is the largest beta
%   that still meets the catastrophic target.

if nargin < 3, scale = 1; end
q = @(lam) 1 - exp(-lam * scale * T);

qg = q(rp.lambda_gen);
qccf = q(rp.beta_ccf * rp.lambda_gen);
q_both = 1 - (1 - qg^2) * (1 - qccf);
q_apu = 1 - (1 - rp.p_apu_start) * (1 - q(rp.lambda_apu));
q_efc2 = q(rp.lambda_efc)^2;
q_nomain = 1 - (1 - q_both * q_apu) * (1 - q_efc2);
q_nobatt = 1 - (1 - q(rp.lambda_batt)) * (1 - q(rp.lambda_bcru));
q_hve = q(rp.lambda_hve);

P = 1 - (1 - q_hve) * (1 - q_nomain * q_nobatt);

% split essential bus: lose both halves
lose_half_given_nomain = 1 - (1 - q_hve) * (1 - q_nobatt);
P_indep = q_nomain * lose_half_given_nomain^2 + (1 - q_nomain) * q_hve^2;
q_bus_ccf = q(rp.beta_bus * rp.lambda_hve);
P_split = 1 - (1 - P_indep) * (1 - q_bus_ccf);

r.T_h = T;
r.P_mission = P;
r.P_per_fh = P / T;
r.P_split_mission = P_split;
r.P_split_per_fh = P_split / T;
r.P_split_indep_per_fh = P_indep / T;
r.split_beta_max = max(rp.target_catastrophic * T - P_indep, 0) / (rp.lambda_hve * scale * T);
r.contrib.hve_fault = q_hve / T;
r.contrib.no_main_and_no_batt = q_nomain * q_nobatt / T;
r.q = struct('both_gens', q_both, 'apu_unavail', q_apu, 'efc_both', q_efc2, ...
             'no_main', q_nomain, 'no_batt', q_nobatt, 'hve', q_hve);
end
