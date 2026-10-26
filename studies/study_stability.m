function res = study_stability(tp, figdir)
%STUDY_STABILITY  Constant-power-load instability of the radar power supply.
%
%   A tightly regulated converter draws constant power, so when the bus
%   voltage rises it draws LESS current: a negative incremental resistance
%   -V^2/P. Feeding it through an LC input filter makes an oscillator that
%   goes unstable once P is large enough. This study:
%     1. sweeps the radar power and tracks the least-damped eigenvalue of
%        the linearised bus, with and without an R-C damping branch;
%     2. confirms the prediction in the time domain (25 kW, undamped vs damped);
%     3. plots the Middlebrook impedance comparison |Zout| vs |Zin|.
%   The other loads on this bus are 20 kW resistive.

if nargin < 1 || isempty(tp), tp = transient_params(); end
if nargin < 2, figdir = ''; end
G = 20e3 / tp.Vref^2;
P = (0:1:80) * 1e3;

maxre = zeros(2, numel(P));
fosc = zeros(2, numel(P));
for d = 1:2
    tpd = tp; tpd.damp = (d == 2);
    for k = 1:numel(P)
        A = linearize_hvdc(tpd, G, P(k));
        e = eig(A);
        [maxre(d, k), i] = max(real(e));
        fosc(d, k) = abs(imag(e(i))) / (2 * pi);
    end
end

pcrit = NaN(1, 2);
for d = 1:2
    k = find(maxre(d, :) > 0, 1, 'first');
    if ~isempty(k)
        pcrit(d) = interp1(maxre(d, k-1:k), P(k-1:k), 0);
    else
        pcrit(d) = inf;
    end
end
% textbook estimate for an ideal LC filter + CPL (source impedance ignored)
pcrit_simple = tp.R_f * tp.C_f * tp.Vref^2 / tp.L_f;

% ---- time domain: radar steps 10 kW -> 25 kW at 20 ms -----------------
P_test = 25e3;
inp = @(t) struct('G', G, 'P', 10e3 + (P_test - 10e3) * (t >= 0.02), 'connected', true);
tpu = tp; tpu.damp = false;
ru = simulate_hvdc(tpu, 0.12, inp);
tpd = tp; tpd.damp = true;
rd = simulate_hvdc(tpd, 0.12, inp);
tail = ru.t > 0.08;
res.undamped_osc_pp_V = max(ru.v_cf(tail)) - min(ru.v_cf(tail));
tail = rd.t > 0.08;
res.damped_osc_pp_V = max(rd.v_cf(tail)) - min(rd.v_cf(tail));

% ---- Middlebrook --------------------------------------------------------
f = logspace(0, 5, 600);
[Zo, Zi_u] = hvdc_impedances(tpu, G, P_test, f);
[~, Zi_d] = hvdc_impedances(tpd, G, P_test, f);
res.min_sep_dB_undamped = min(20 * log10(abs(Zi_u) ./ abs(Zo)));
res.min_sep_dB_damped = min(20 * log10(abs(Zi_d) ./ abs(Zo)));
% The impedances overlap near the generator/bus-capacitor resonance, so
% Middlebrook's (sufficient, conservative) condition is not met even with
% damping. The exact test is the Nyquist plot of the minor-loop gain
% T = Zout/Zin (valid here because the damped PSU is stable on its own):
% report its phase margin and vector margin (closest approach to -1).
fm = logspace(0, 5, 4000);
[Zo_m, Zi_m] = hvdc_impedances(tpd, G, P_test, fm);
T = Zo_m ./ Zi_m;
[res.minor_loop_vector_margin, iv] = min(abs(1 + T));
res.minor_loop_vm_freq_Hz = fm(iv);
k = find(abs(T) > 1);
if isempty(k)
    res.minor_loop_pm_deg = inf;
else
    res.minor_loop_pm_deg = min(180 - abs(angle(T(k)) * 180 / pi));
end
res.bus_resonance_Hz = 1 / (2 * pi * sqrt(tp.L_s * tp.C_dc));

res.P_W = P;
res.max_real = maxre;
res.f_osc = fosc;
res.P_crit_undamped_W = pcrit(1);
res.P_crit_damped_W = pcrit(2);
res.P_crit_simple_W = pcrit_simple;
res.P_test_W = P_test;
res.undamped_stable_at_test = interp1(P, maxre(1, :), P_test) < 0;
res.damped_stable_at_test = interp1(P, maxre(2, :), P_test) < 0;

if ~isempty(figdir)
    cc = eps_colors();
    fig = figure('Visible', 'off', 'Position', [50 50 1250 430], 'Color', 'w');
    subplot(1, 3, 1); hold on
    plot(P / 1e3, maxre(1, :), '-', 'Color', cc.s2, 'LineWidth', 2);
    plot(P / 1e3, maxre(2, :), '-', 'Color', cc.s1, 'LineWidth', 2);
    plot([0 80], [0 0], ':', 'Color', cc.crit, 'LineWidth', 1.2);
    if isfinite(pcrit(1))
        plot(pcrit(1) / 1e3, 0, 'o', 'MarkerSize', 8, 'MarkerFaceColor', cc.s2, 'MarkerEdgeColor', 'w');
        text(pcrit(1) / 1e3 + 2, -60, sprintf('unstable above %.1f kW', pcrit(1) / 1e3), 'FontSize', 8);
    end
    xlabel('Radar PSU power (kW)'); ylabel('Largest real part of eigenvalues (1/s)');
    title('Small-signal stability vs radar power', 'FontSize', 9);
    legend({'LC filter only', 'With R-C damping branch', 'stability boundary'}, 'Location', 'northwest', 'FontSize', 7);
    ylim([-250 600]); grid on; box on;

    subplot(1, 3, 2); hold on
    plot(ru.t * 1e3, ru.v_cf, '-', 'Color', cc.s2, 'LineWidth', 1.2);
    plot(rd.t * 1e3, rd.v_cf, '-', 'Color', cc.s1, 'LineWidth', 1.8);
    plot([20 20], [0 400], ':', 'Color', cc.ink2, 'HandleVisibility', 'off');
    text(21, 380, 'radar 10 -> 25 kW', 'FontSize', 7, 'Color', cc.ink2);
    xlabel('Time (ms)'); ylabel('Radar PSU filter voltage (V)');
    title('Time domain at 25 kW', 'FontSize', 9);
    legend({'LC filter only', 'With damping'}, 'Location', 'southwest', 'FontSize', 7);
    ylim([100 400]); grid on; box on;

    subplot(1, 3, 3);
    loglog(f, abs(Zo), '-', 'Color', cc.ink, 'LineWidth', 1.8); hold on
    loglog(f, abs(Zi_u), '-', 'Color', cc.s2, 'LineWidth', 1.6);
    loglog(f, abs(Zi_d), '-', 'Color', cc.s1, 'LineWidth', 1.8);
    xlabel('Frequency (Hz)'); ylabel('Impedance magnitude (\Omega)');
    title(sprintf('Impedances at 25 kW: overlap at bus resonance, PM %.0f%s', ...
        res.minor_loop_pm_deg, char(176)), 'FontSize', 9);
    legend({'|Z_{out}| bus (source side)', '|Z_{in}| radar PSU, LC only', '|Z_{in}| radar PSU, damped'}, ...
        'Location', 'southwest', 'FontSize', 7);
    xlim([1 1e5]); grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_stability.png'));
end
end
