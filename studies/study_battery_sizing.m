function res = study_battery_sizing(p, L, m, figdir)
%STUDY_BATTERY_SIZING  How big must the battery be to survive a dual-
%   generator failure with no APU?
%
%   Design case: both generators fail 30 min before touchdown and the APU
%   fails to start. The battery alone carries the flight-critical loads for
%   8 min of MISSION, 15 min of RTB and the 7 min APPROACH and landing
%   (the same timeline as scenario S4). Requirement: no BMS cut-off for
%   p.req.emergency_endurance_min minutes.
%
%   Four corner cases: beginning / end of life (80 % capacity, 1.5 x
%   resistance) at 25 degC and -20 degC. The design value of Np is the
%   smallest number of parallel strings that passes all four.

if nargin < 1 || isempty(p), p = eps_params(); end
if nargin < 2 || isempty(L), L = load_table(); end
if nargin < 3 || isempty(m), m = mission_profile(); end
if nargin < 4, figdir = ''; end

prof = emergency_load_profile(p, L, m, {'MISSION', 'RTB', 'APPROACH'}, [8 15 7]);
assert(abs(sum(prof.dur_s) / 60 - p.req.emergency_endurance_min) < 1e-9, ...
    'Profile length must match the endurance requirement');

cases = struct('name', {'BOL 25 degC', 'BOL -20 degC', 'EOL 25 degC', 'EOL -20 degC'}, ...
               'T', {25, -20, 25, -20}, 'age_Q', {1, 1, 0.8, 0.8}, 'age_R', {1, 1, 1.5, 1.5});
Np_list = 8:40;
nc = numel(cases);
pass = false(nc, numel(Np_list));
t_cut = NaN(nc, numel(Np_list));
endur = NaN(nc, numel(Np_list));
reason = cell(nc, numel(Np_list));
cruise = emergency_load_profile(p, L, m, {'RTB'}, 1);

for c = 1:nc
    for j = 1:numel(Np_list)
        b = p.batt;
        b.Np = Np_list(j);
        b.T_degC = cases(c).T;
        b.age_Q = cases(c).age_Q;
        b.age_R = cases(c).age_R;
        r = simulate_battery_profile(b, prof, 1);
        pass(c, j) = r.survived;
        t_cut(c, j) = r.t_cut / 60;
        reason{c, j} = r.reason;
        % endurance at constant cruise (RTB) essential load, up to 3 h
        e = simulate_battery_profile(b, cruise, 5, 3 * 3600);
        endur(c, j) = e.t_cut / 60;
    end
end

Np_min = NaN(1, nc);
first_fail_reason = cell(1, nc);
for c = 1:nc
    j = find(pass(c, :), 1, 'first');
    if ~isempty(j)
        Np_min(c) = Np_list(j);
        if j > 1
            first_fail_reason{c} = reason{c, j - 1};
        else
            first_fail_reason{c} = '';
        end
    end
end
Np_design = max(Np_min);

cell_mass = p.batt.m_cell;
res.cases = cases;
res.Np_list = Np_list;
res.pass = pass;
res.t_cut = t_cut;
res.endurance_cruise_min = endur;
res.reason = reason;
res.Np_min = Np_min;
res.limiting_reason = first_fail_reason;
res.Np_design = Np_design;
res.Np_configured = p.batt.Np;
res.prof = prof;
res.pack_mass_kg = p.batt.Ns * Np_design * cell_mass * p.batt.pack_mass_factor;
res.pack_energy_kWh = p.batt.Ns * Np_design * p.batt.Q_cell * 3.65 / 1e3;
res.pack_Ah = Np_design * p.batt.Q_cell;
% energy-only estimate: what the pack would weigh if only energy mattered
E_req_Wh = sum(prof.P_batt .* prof.dur_s) / 3600;
res.E_required_kWh = E_req_Wh / 1e3;

% ---- figure ------------------------------------------------------------
if ~isempty(figdir)
    c = eps_colors();
    cols = {c.s1, c.s2, c.s3, c.s7};
    styles = {'-', '-', '--', '--'};
    fig = figure('Visible', 'off', 'Position', [50 50 1100 480], 'Color', 'w');
    subplot(1, 2, 1); hold on
    for k = 1:nc
        plot(Np_list, endur(k, :), styles{k}, 'Color', cols{k}, 'LineWidth', 2);
    end
    plot([Np_list(1) Np_list(end)], p.req.emergency_endurance_min * [1 1], ':', 'Color', c.crit, 'LineWidth', 1.2);
    plot(Np_design * [1 1], [0 120], ':', 'Color', c.ink2, 'LineWidth', 1);
    text(Np_design + 0.4, 112, sprintf('design Np = %d', Np_design), 'FontSize', 8, 'Color', c.ink2);
    text(Np_list(end), p.req.emergency_endurance_min + 3, '30 min requirement', 'FontSize', 8, ...
        'Color', c.crit, 'HorizontalAlignment', 'right');
    ylim([0 120]); xlim([Np_list(1) Np_list(end)]);
    xlabel('Parallel strings Np (74 cells in series each)');
    ylabel('Endurance at cruise essential load (min)');
    title('Battery-only endurance vs pack size', 'FontSize', 10);
    legend({cases.name}, 'Location', 'northwest', 'FontSize', 8);
    grid on; box on;

    subplot(1, 2, 2); hold on
    b = p.batt; b.Np = Np_design;
    leg = {};
    for k = 1:nc
        b.T_degC = cases(k).T; b.age_Q = cases(k).age_Q; b.age_R = cases(k).age_R;
        r = simulate_battery_profile(b, prof, 1);
        plot(r.t / 60, r.v_cell, styles{k}, 'Color', cols{k}, 'LineWidth', 2);
        leg{end+1} = cases(k).name; %#ok<AGROW>
    end
    plot([0 30], p.batt.v_cell_min * [1 1], ':', 'Color', c.crit, 'LineWidth', 1.2);
    text(0.5, p.batt.v_cell_min + 0.03, 'BMS cut-off 3.0 V', 'FontSize', 8, 'Color', c.crit);
    xlabel('Time on battery (min)');
    ylabel('Loaded cell voltage (V)');
    title(sprintf('Cell voltage through the 30 min emergency, Np = %d', Np_design), 'FontSize', 10);
    legend(leg, 'Location', 'northeast', 'FontSize', 8);
    xlim([0 30]); grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_battery_sizing.png'));
end
end
