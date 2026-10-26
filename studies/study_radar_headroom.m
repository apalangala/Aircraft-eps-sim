function res = study_radar_headroom(p, L, m, figdir)
%STUDY_RADAR_HEADROOM  How much radar power can the system carry?
%
%   Sweeps the AESA radar's average power in the MISSION phase, with the
%   ECS cooling load following it (ECS = 8 kW + 0.4 x radar, see
%   load_table.m), and finds the radar power at which a source reaches
%   100 % of its continuous rating in three configurations:
%
%     A  Normal: both generators, every load on.
%        -> beyond this you need bigger generators or a third one.
%     B  One generator lost, APU online, every load on (worst of GEN1 / GEN2 lost).
%     C  One generator lost, no APU, non-essential (P3) loads shed, all
%        flight-critical and mission loads at full power.
%        -> the "N-1" mission capability: lose a generator and keep fighting.

if nargin < 1 || isempty(p), p = eps_params(); end
if nargin < 2 || isempty(L), L = load_table(); end
if nargin < 3 || isempty(m), m = mission_profile(); end
if nargin < 4, figdir = ''; end

info = load_info(L);
ph = find(strcmp(m.names, 'MISSION'), 1);
i_radar = find(strcmp({L.name}, 'AESA radar'), 1);
i_ecs = find(strcmp({L.name}, 'ECS / liquid cooling'), 1);
Pr = 0:0.5:60;                                   % [kW]

cfg(1).name = 'A  Normal: 2 generators, all loads';
cfg(1).cases = {[true true false]};
cfg(1).p3 = true;
cfg(2).name = 'B  1 generator lost + APU, all loads';
cfg(2).cases = {[false true true], [true false true]};
cfg(2).p3 = true;
cfg(3).name = 'C  1 generator lost, no APU, P3 shed (N-1)';
cfg(3).cases = {[false true false], [true false false]};
cfg(3).p3 = false;

loading = zeros(numel(cfg), numel(Pr));
binding = cell(numel(cfg), numel(Pr));
caps = [p.gen(1).P_rated, p.gen(2).P_rated, p.apu.P_rated, inf];
for c = 1:numel(cfg)
    frac = ones(1, info.n);
    if ~cfg(c).p3
        frac(info.prio == 3) = 0;
    end
    for j = 1:numel(Pr)
        D = info.D(:, ph)';
        D(i_radar) = Pr(j) * 1e3;
        D(i_ecs) = (8 + 0.4 * Pr(j)) * 1e3;
        worst = 0;
        for q = 1:numel(cfg(c).cases)
            hv = cfg(c).cases{q};
            h.gen_ok = hv(1:2); h.apu_ok = hv(3); h.batt_ok = true;
            h.dcdc_ok = [true true]; h.inv_ok = true;
            bm = bus_manager(h);
            pf = power_flow(p, L, bm, h, D, frac, 0, info);
            [u, s] = max(pf.P_src ./ caps);
            if u > worst
                worst = u;
                binding{c, j} = pf.src_names{s};
            end
        end
        loading(c, j) = worst;
    end
end

thr = NaN(1, numel(cfg));
for c = 1:numel(cfg)
    k = find(loading(c, :) > 1, 1, 'first');
    if ~isempty(k) && k > 1
        thr(c) = interp1(loading(c, k-1:k), Pr(k-1:k), 1);
    elseif isempty(k)
        thr(c) = inf;
    else
        thr(c) = 0;
    end
end

base = info.D(i_radar, ph) / 1e3;
res.Pr_kW = Pr;
res.loading = loading;
res.cfg_names = {cfg.name};
res.threshold_kW = thr;
res.baseline_radar_kW = base;
res.loading_at_baseline = interp1(Pr, loading', base);
res.binding_at_threshold = cell(1, numel(cfg));
for c = 1:numel(cfg)
    k = find(Pr >= min(thr(c), Pr(end)), 1, 'first');
    res.binding_at_threshold{c} = binding{c, k};
end

if ~isempty(figdir)
    cc = eps_colors();
    cols = {cc.s1, cc.s3, cc.s2};
    fig = figure('Visible', 'off', 'Position', [50 50 900 520], 'Color', 'w');
    hold on
    for c = 1:numel(cfg)
        plot(Pr, loading(c, :) * 100, '-', 'Color', cols{c}, 'LineWidth', 2.2);
    end
    plot([Pr(1) Pr(end)], [100 100], ':', 'Color', cc.crit, 'LineWidth', 1.2);
    plot(base * [1 1], [0 160], ':', 'Color', cc.ink2, 'LineWidth', 1);
    text(base + 0.6, 152, sprintf('baseline radar %g kW', base), 'FontSize', 8, 'Color', cc.ink2);
    for c = 1:numel(cfg)
        if isfinite(thr(c))
            plot(thr(c), 100, 'o', 'MarkerSize', 8, 'MarkerFaceColor', cols{c}, ...
                'MarkerEdgeColor', 'w', 'LineWidth', 1.5, 'HandleVisibility', 'off');
            text(thr(c), 92 - 8 * (c - 1), sprintf('%.1f kW', thr(c)), 'FontSize', 9, ...
                'Color', cc.ink, 'HorizontalAlignment', 'center');
        end
    end
    ylim([0 160]); xlim([Pr(1) Pr(end)]);
    xlabel('Radar average power in the mission phase (kW)');
    ylabel('Most-loaded source (% of continuous rating)');
    title('Radar power headroom (ECS cooling scales with radar power)', 'FontSize', 10);
    legend([cfg.name {'100 % continuous rating'}], 'Location', 'northwest', 'FontSize', 8);
    grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_radar_headroom.png'));
end
end
