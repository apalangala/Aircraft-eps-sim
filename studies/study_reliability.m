function res = study_reliability(m, figdir)
%STUDY_RELIABILITY  Probability of losing the essential bus per flight hour.
%
%   1. Analytic fault tree (src/analysis/reliability_fault_tree.m) for the
%      baseline architecture and for a split essential bus.
%   2. Monte Carlo with event timing (src/analysis/reliability_montecarlo.m),
%      run at failure rates scaled up x1000 so that failures actually show
%      up in a few million samples:
%        a) a check case (no APU running failures, instant APU start) where
%           event order cannot matter, so Monte Carlo must agree with the
%           fault tree within its confidence interval;
%        b) the full model, where the Monte Carlo is expected to come out a
%           little BELOW the fault tree because the tree is conservative.
%   Results are compared with the 1e-9 per flight hour target that
%   certification guidance (CS-25.1309 / AC 25.1309-1) uses for
%   catastrophic failure conditions.

if nargin < 1 || isempty(m), m = mission_profile(); end
if nargin < 2, figdir = ''; end
rp = reliability_params();
T = m.T_total / 3600;

ft = reliability_fault_tree(rp, T);

scale = 1000;
n = 2e6;
rp_chk = rp; rp_chk.lambda_apu = 0; rp_chk.apu_start_time_h = 0;
ft_chk = reliability_fault_tree(rp_chk, T, scale);
mc_chk = reliability_montecarlo(rp_chk, T, scale, n, 1);
ft_sc = reliability_fault_tree(rp, T, scale);
mc_sc = reliability_montecarlo(rp, T, scale, n, 2);

res.T_h = T;
res.baseline_per_fh = ft.P_per_fh;
res.split_per_fh = ft.P_split_per_fh;
res.split_indep_per_fh = ft.P_split_indep_per_fh;
res.split_beta_max = ft.split_beta_max;
res.beta_bus = rp.beta_bus;
res.contrib = ft.contrib;
res.target = rp.target_catastrophic;
res.baseline_meets_target = ft.P_per_fh <= rp.target_catastrophic;
res.split_meets_target = ft.P_split_per_fh <= rp.target_catastrophic;
res.check_ft = ft_chk.P_mission;
res.check_mc = mc_chk.P_mission;
res.check_ci95 = mc_chk.ci95;
res.check_agrees = abs(mc_chk.P_mission - ft_chk.P_mission) <= mc_chk.ci95;
res.full_ft = ft_sc.P_mission;
res.full_mc = mc_sc.P_mission;
res.full_ci95 = mc_sc.ci95;
res.scale = scale;
res.n = n;

if ~isempty(figdir)
    cc = eps_colors();
    fig = figure('Visible', 'off', 'Position', [50 50 1150 450], 'Color', 'w');
    subplot(1, 2, 1);
    vals = [ft.contrib.hve_fault, ft.contrib.no_main_and_no_batt, ft.P_per_fh, ft.P_split_per_fh];
    labels = {'Busbar fault', 'No main source + no battery', 'Baseline total', sprintf('Split bus (%.1f %% common cause)', rp.beta_bus * 100)};
    hb = barh(1:4, log10(vals), 0.6);
    set(hb, 'FaceColor', cc.s1, 'EdgeColor', 'none', 'BaseValue', -13);
    hold on
    plot(log10(rp.target_catastrophic) * [1 1], [0.4 4.6], '-', 'Color', cc.crit, 'LineWidth', 1.5);
    text(log10(rp.target_catastrophic) + 0.1, 4.45, 'catastrophic target 1e-9 / fh', 'FontSize', 8, 'Color', cc.crit);
    for k = 1:4
        text(log10(vals(k)) + 0.1, k, sprintf('%.1e', vals(k)), 'FontSize', 8, 'Color', cc.ink);
    end
    set(gca, 'YTick', 1:4, 'YTickLabel', labels, 'YDir', 'reverse', 'XTick', -13:-5, ...
        'XTickLabel', arrayfun(@(x) sprintf('1e%d', x), -13:-5, 'UniformOutput', false));
    xlim([-13 -5]); ylim([0.4 4.6]);
    xlabel('Probability of losing the essential bus (per flight hour)');
    title('Fault tree: what drives the risk', 'FontSize', 10);
    grid on; box on;

    subplot(1, 2, 2); hold on
    y = [ft_chk.P_mission, mc_chk.P_mission; ft_sc.P_mission, mc_sc.P_mission];
    hb = bar(1:2, y, 0.7);
    set(hb(1), 'FaceColor', cc.s1, 'EdgeColor', 'none');
    set(hb(2), 'FaceColor', cc.s3, 'EdgeColor', 'none');
    off = 0.15;   % bar offset for the Monte Carlo series (two groups)
    mcv = [mc_chk.P_mission mc_sc.P_mission];
    ci = [mc_chk.ci95 mc_sc.ci95];
    for k = 1:2
        x = k + off;
        plot([x x], mcv(k) + [-1 1] * ci(k), '-', 'Color', cc.ink, 'LineWidth', 1.4, 'HandleVisibility', 'off');
        plot(x + [-0.04 0.04], (mcv(k) - ci(k)) * [1 1], '-', 'Color', cc.ink, 'LineWidth', 1.4, 'HandleVisibility', 'off');
        plot(x + [-0.04 0.04], (mcv(k) + ci(k)) * [1 1], '-', 'Color', cc.ink, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    end
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Check case (order-free)', 'Full model'});
    ylabel(sprintf('P(lose HVE in one mission), rates x%d', scale));
    title('Monte Carlo vs fault tree (95 % interval)', 'FontSize', 10);
    legend({'Fault tree', 'Monte Carlo'}, 'Location', 'northwest', 'FontSize', 8);
    grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_reliability.png'));
end
end
