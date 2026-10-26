function fig = plot_scenario(out, fname)
%PLOT_SCENARIO  Five-panel time history of one scenario run.
%
%   (a) source power, (b) 270 V bus voltages, (c) 28 V bus voltage,
%   (d) battery state of charge, (e) load status map.
%   Mission phases are shaded; fault events are marked with vertical lines.

c = eps_colors();
lg = out.log;
m = out.m;
L = out.L;
lim = out.p.req.mil704;
tm = lg.t / 60;
T = tm(end) + out.p.dt / 60;
ev = out.sc.events;

fig = figure('Visible', 'off', 'Position', [50 50 1100 1400], 'Color', 'w');

% ---- (a) source power ---------------------------------------------------
ax1 = subplot(5, 1, 1);
Pk = lg.P_src / 1e3;
ymax = max(10, ceil(max(sum(Pk, 1)) / 10) * 10 + 10);
shade_phases(m, [0 ymax], true);
h = area(tm, Pk');
cols = {c.s1, c.s2, c.s3, c.s4};
for k = 1:4
    set(h(k), 'FaceColor', cols{k}, 'EdgeColor', 'none');
end
plot(tm, sum(lg.P_full, 1) / 1e3, '--', 'Color', c.ink, 'LineWidth', 1);
mark_events(ev, [0 ymax]);
ylim([0 ymax]); xlim([0 T]);
ylabel('Power (kW)');
legend([h(:)' ], {'GEN1', 'GEN2', 'APU', 'Battery (BCRU out)'}, 'Location', 'northwest', 'FontSize', 7);
text(0.995, 0.94, 'dashed: total load demand before shedding', 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'FontSize', 7, 'Color', c.ink2);
title(sprintf('%s: %s', strrep(out.sc.name, '_', '\_'), out.sc.title), 'FontSize', 10);
box on; grid on;

% ---- (b) 270 V buses ----------------------------------------------------
subplot(5, 1, 2);
shade_phases(m, [0 300]);
V = lg.V; V(V < 1) = NaN;
plot(tm, V(1, :), '-', 'Color', c.s1, 'LineWidth', 1.6);
plot(tm, V(2, :), '-', 'Color', c.s2, 'LineWidth', 1.6);
plot(tm, V(3, :), '-', 'Color', c.s3, 'LineWidth', 1.6);
plot([0 T], lim.hv.ss_min * [1 1], ':', 'Color', c.limit, 'LineWidth', 1);
plot([0 T], lim.hv.ss_max * [1 1], ':', 'Color', c.limit, 'LineWidth', 1);
mark_events(ev, [0 300]);
Vhv = V(1:3, :);
vlive = Vhv(~isnan(Vhv));
if isempty(vlive) || min(vlive) >= 240
    ylim([225 285]);
else
    ylim([0 300]);
end
xlim([0 T]);
ylabel('270 V buses (V)');
legend({'HV1', 'HV2', 'HVE (essential)', 'MIL-STD-704F steady-state limits'}, ...
    'Location', 'southwest', 'Orientation', 'horizontal', 'FontSize', 7);
box on; grid on;

% ---- (c) 28 V bus -------------------------------------------------------
subplot(5, 1, 3);
shade_phases(m, [0 30]);
v = lg.V(4, :); v(v < 1) = NaN;
plot(tm, v, '-', 'Color', c.s7, 'LineWidth', 1.6);
plot([0 T], lim.lv.ss_min * [1 1], ':', 'Color', c.limit, 'LineWidth', 1);
plot([0 T], lim.lv.ss_max * [1 1], ':', 'Color', c.limit, 'LineWidth', 1);
mark_events(ev, [0 30]);
ylim([20 30]); xlim([0 T]);
ylabel('28 V bus (V)');
legend({'LV bus', 'MIL-STD-704F steady-state limits'}, 'Location', 'southwest', 'FontSize', 7);
box on; grid on;

% ---- (d) battery --------------------------------------------------------
subplot(5, 1, 4);
shade_phases(m, [0 100]);
plot(tm, lg.soc * 100, '-', 'Color', c.s4, 'LineWidth', 1.8);
plot([0 T], out.p.batt.soc_min * 100 * [1 1], ':', 'Color', c.crit, 'LineWidth', 1);
mark_events(ev, [0 100]);
ylim([0 100]); xlim([0 T]);
ylabel('Battery SOC (%)');
text(0.005, 0.12, sprintf('BMS cut-off %.0f %%', out.p.batt.soc_min * 100), 'Units', 'normalized', ...
    'FontSize', 7, 'Color', c.crit);
box on; grid on;

% ---- (e) load status ----------------------------------------------------
subplot(5, 1, 5);
st = lg.status;
st(lg.P_full == 0 & st >= 0) = 3;      % no demand in this phase
stride = max(1, ceil(size(st, 2) / 2000));   % keep the image small enough to render
keep = 1:stride:size(st, 2);
st = st(:, keep);
tk = tm(keep);
img = zeros(size(st, 1), size(st, 2), 3);
cmap = {c.crit, c.warn, c.reduced, c.full, [1 1 1]};   % -1 dead, 0 shed, 1 reduced, 2 full, 3 idle
vals = [-1 0 1 2 3];
for q = 1:5
    mask = st == vals(q);
    for ch = 1:3
        layer = img(:, :, ch);
        layer(mask) = cmap{q}(ch);
        img(:, :, ch) = layer;
    end
end
image([tk(1) tk(end)], [1 numel(L)], img);
set(gca, 'YDir', 'reverse', 'YTick', 1:numel(L), 'YTickLabel', ...
    arrayfun(@(x) sprintf('P%d  %s', x.prio, x.name), L, 'UniformOutput', false), 'FontSize', 7);
xlim([0 T]);
xlabel('Mission time (min)');
hold on
for q = 1:4
    patch(NaN, NaN, cmap{q}, 'EdgeColor', [0.6 0.6 0.6]);
end
legend({'bus dead', 'shed', 'reduced mode', 'full power'}, 'Location', 'eastoutside', 'FontSize', 7);
box on;

linkaxes_x(fig, T);
if nargin > 1 && ~isempty(fname)
    save_fig(fig, fname);
end
end

function mark_events(ev, yl)
c = eps_colors();
for k = 1:numel(ev)
    x = ev(k).t / 60;
    plot([x x], yl, '-', 'Color', c.crit, 'LineWidth', 1, 'HandleVisibility', 'off');
end
end

function linkaxes_x(fig, T)
ax = findobj(fig, 'Type', 'axes');
for k = 1:numel(ax)
    if ~strcmp(get(ax(k), 'Tag'), 'legend')
        set(ax(k), 'XLim', [0 T]);
    end
end
end
