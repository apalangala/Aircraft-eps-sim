function fig = plot_single_line_diagram(p, fname)
%PLOT_SINGLE_LINE_DIAGRAM  Draw the electrical architecture (single-line diagram).
if nargin < 1 || isempty(p), p = eps_params(); end
c = eps_colors();
fig = figure('Visible', 'off', 'Position', [50 50 1200 760], 'Color', 'w');
ax = axes('Position', [0 0 1 1]);
hold on; axis off; axis equal
xlim([0 120]); ylim([0 76]);

% ---- sources ----
src_box(10, 66, sprintf('GEN1\n%.0f kW', p.gen(1).P_rated / 1e3), c.s1);
src_box(60, 66, sprintf('APU GEN\n%.0f kW', p.apu.P_rated / 1e3), c.s3);
src_box(110, 66, sprintf('GEN2\n%.0f kW', p.gen(2).P_rated / 1e3), c.s2);

% ---- main buses ----
busbar(2, 34, 48, 'HV1  270 V DC', c.s1);
busbar(52, 68, 48, 'TIE', c.ink2);
busbar(86, 118, 48, 'HV2  270 V DC', c.s2);
busbar(28, 92, 28, '', c.s3);
text(47, 29.8, 'HVE  270 V DC essential', 'FontSize', 8, 'FontWeight', 'bold', 'Color', c.s3);
busbar(4, 40, 8, 'LV  28 V DC', c.s7);
busbar(84, 116, 8, 'AC  115 V 400 Hz', c.s5);

% ---- contactors ----
wire([10 10], [62 48]); contactor(10, 55, 'GLC1');
wire([110 110], [62 48]); contactor(110, 55, 'GLC2');
wire([60 60], [62 48]); contactor(60, 55, 'ALC');
wire([34 52], [48 48]); contactor(43, 48, 'BTC1', true);
wire([68 86], [48 48]); contactor(77, 48, 'BTC2', true);
wire([24 24 40 40], [48 38 38 28]); contactor(24, 42, 'EFC1');
wire([96 96 80 80], [48 38 38 28]); contactor(96, 42, 'EFC2');

% ---- battery ----
src_box(60, 14, sprintf('Li-ion battery\n%dS%dP', p.batt.Ns, p.batt.Np), c.s4);
wire([60 60], [18 28]); conv_box(60, 22, 'BCRU');

% ---- converters ----
wire([46 46 22 22], [28 20 20 8]); conv_box(30, 20, sprintf('DC/DC A+B\n2 x %.1f kW', p.dcdc(1).P_rated / 1e3));
wire([112 112 100 100], [48 18 18 8]); conv_box(112, 30, sprintf('INV\n%.0f kW', p.inv.P_rated / 1e3));

% ---- load labels ----
lab = @(x, y, s) text(x, y, s, 'FontSize', 7.5, 'Color', c.ink2, 'HorizontalAlignment', 'center');
lab(18, 44.5, 'ECS, bay heaters');
lab(102, 44.5, 'Radar, payload bay');
lab(86, 25.3, 'Flight controls, fuel pumps, landing gear');
lab(22, 4.5, 'Avionics, C2 datalink, FADEC, SATCOM, lighting');
lab(100, 4.5, 'EO/IR turret, ice protection');
text(2, 74, 'Generic twin-engine military UAV: 270 V DC primary distribution', 'FontSize', 11, 'FontWeight', 'bold', 'Color', c.ink);
text(2, 71.3, 'Generators are never paralleled; HVE is fed from HV1, else HV2, else the battery (no-break).', 'FontSize', 8, 'Color', c.ink2);

if nargin > 1 && ~isempty(fname)
    save_fig(fig, fname);
end
end

function src_box(x, y, s, col)
rectangle('Position', [x - 7, y - 4, 14, 8], 'Curvature', 0.3, 'FaceColor', min(col * 0.25 + 0.75, 1), 'EdgeColor', col, 'LineWidth', 1.5);
text(x, y, s, 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
end

function conv_box(x, y, s)
rectangle('Position', [x - 6, y - 3, 12, 6], 'FaceColor', [1 1 1], 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.2);
text(x, y, s, 'HorizontalAlignment', 'center', 'FontSize', 7);
end

function busbar(x0, x1, y, s, col)
plot([x0 x1], [y y], '-', 'Color', col, 'LineWidth', 5);
if ~isempty(s)
    text(x0, y + 1.8, s, 'FontSize', 8, 'FontWeight', 'bold', 'Color', col);
end
end

function wire(x, y)
plot(x, y, '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.2);
end

function contactor(x, y, s, above)
rectangle('Position', [x - 1.4, y - 1.4, 2.8, 2.8], 'FaceColor', [1 1 1], 'EdgeColor', [0.1 0.1 0.1], 'LineWidth', 1.2);
if nargin > 3 && above
    text(x, y + 2.8, s, 'FontSize', 7, 'Color', [0.2 0.2 0.2], 'HorizontalAlignment', 'center');
else
    text(x + 2, y, s, 'FontSize', 7, 'Color', [0.2 0.2 0.2]);
end
end
