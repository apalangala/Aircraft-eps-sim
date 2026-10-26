function res = study_pulsed_radar(tp, figdir)
%STUDY_PULSED_RADAR  Energy buffer needed so a pulsed radar keeps the
%   270 V bus inside the MIL-STD-704F ripple limit.
%
%   The radar does not draw a steady 25 kW. Here it draws 50 kW bursts at
%   50 % duty, 10 Hz (25 kW average). If its power supply passes those
%   bursts straight to the bus, the generator sees a 50 kW load switching
%   on and off ten times a second.
%
%   A storage capacitor inside the radar power supply can smooth this: the
%   supply then draws a low-pass-filtered version of the radar power from
%   the bus (time constant tau) and the capacitor makes up the difference.
%   Longer tau -> smoother bus, but more stored energy needed. This study
%   sweeps tau, measures bus ripple (amplitude about the mean, limit 6 V)
%   and the energy the buffer must swing, and picks the smallest buffer
%   that meets the limit.

if nargin < 1 || isempty(tp), tp = transient_params(); end
if nargin < 2, figdir = ''; end
tp.damp = true;
lim = mil704_limits();
G = 20e3 / tp.Vref^2;           % other loads on this bus
P_pk = 50e3; duty = 0.5; f_prf = 10;
P_avg = P_pk * duty;
T_end = 0.7;
t_eval = 0.4;                   % measure over the last 0.3 s (steady state)
taus = [0 0.002 0.005 0.01 0.02 0.05 0.1 0.2];
% storage capacitor operating window behind the PSU's own converter
V_hi = 400; V_lo = 300;

N = round(T_end / tp.dt) + 1;
t = (0:N-1) * tp.dt;
P_radar = P_pk * (mod(t * f_prf, 1) < duty);

ripple = zeros(size(taus));
E_buf = zeros(size(taus));
P_draw_pp = zeros(size(taus));
traces = cell(size(taus));
for k = 1:numel(taus)
    tau = taus(k);
    if tau == 0
        P_draw = P_radar;
    else
        a = exp(-tp.dt / tau);
        P_draw = zeros(1, N);
        y = P_avg;
        for i = 1:N
            P_draw(i) = y;
            y = a * y + (1 - a) * P_radar(i);
        end
    end
    inp = @(tt) struct('G', G, 'P', P_draw, 'connected', true);
    x0 = hvdc_equilibrium(tp, G, P_avg);
    r = simulate_hvdc(tp, T_end, inp, x0);
    sel = t >= t_eval;
    vs = r.v(sel);
    ripple(k) = max(abs(vs - mean(vs)));
    Eb = cumsum(P_draw(sel) - P_radar(sel)) * tp.dt;
    E_buf(k) = max(Eb) - min(Eb);
    P_draw_pp(k) = max(P_draw(sel)) - min(P_draw(sel));
    traces{k} = r.v;
end

ok = ripple <= lim.hv.ripple_max;
k = find(ok, 1, 'first');
if isempty(k)
    tau_req = NaN; E_req = NaN;
elseif k == 1
    tau_req = 0; E_req = 0;
else
    % interpolate on log(ripple) between the bracketing points
    lr = log(ripple(k-1:k));
    w = (log(lim.hv.ripple_max) - lr(1)) / (lr(2) - lr(1));
    tau_req = taus(k-1) + w * (taus(k) - taus(k-1));
    E_req = E_buf(k-1) + w * (E_buf(k) - E_buf(k-1));
end

res.P_peak_W = P_pk; res.duty = duty; res.prf_Hz = f_prf;
res.tau_s = taus;
res.ripple_V = ripple;
res.E_buffer_J = E_buf;
res.P_draw_pp_W = P_draw_pp;
res.ripple_limit_V = lim.hv.ripple_max;
res.tau_required_s = tau_req;
res.E_required_J = E_req;
res.C_required_F = 2 * E_req / (V_hi^2 - V_lo^2);
res.V_window = [V_lo V_hi];
res.ripple_no_buffer_V = ripple(1);

if ~isempty(figdir)
    cc = eps_colors();
    fig = figure('Visible', 'off', 'Position', [50 50 1200 450], 'Color', 'w');
    subplot(1, 2, 1); hold on
    sel = t >= 0.4 & t <= 0.7;
    show = [1, find(taus >= tau_req, 1, 'first')];
    plot((t(sel) - 0.4) * 1e3, traces{show(1)}(sel), '-', 'Color', cc.s2, 'LineWidth', 1.4);
    plot((t(sel) - 0.4) * 1e3, traces{show(2)}(sel), '-', 'Color', cc.s1, 'LineWidth', 1.8);
    plot([0 300], (tp.Vref + lim.hv.ripple_max) * [1 1], ':', 'Color', cc.crit, 'LineWidth', 1.2);
    plot([0 300], (tp.Vref - lim.hv.ripple_max) * [1 1], ':', 'Color', cc.crit, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    xlabel('Time (ms)'); ylabel('270 V bus voltage (V)');
    title('Bus voltage with 50 kW radar bursts at 10 Hz', 'FontSize', 10);
    legend({sprintf('No buffer (ripple %.0f V)', ripple(show(1))), ...
            sprintf('Buffer tau = %.0f ms (ripple %.1f V)', taus(show(2)) * 1e3, ripple(show(2))), ...
            '\pm6 V ripple limit around 270 V'}, 'Location', 'southeast', 'FontSize', 8);
    xlim([0 300]); ylim([200 330]); grid on; box on;

    subplot(1, 2, 2);
    tt = taus(2:end) * 1e3;
    semilogx(tt, ripple(2:end), 'o-', 'Color', cc.s1, 'LineWidth', 2, 'MarkerFaceColor', cc.s1, 'MarkerEdgeColor', 'w', 'MarkerSize', 7);
    hold on
    semilogx([tt(1) tt(end)], lim.hv.ripple_max * [1 1], ':', 'Color', cc.crit, 'LineWidth', 1.2);
    for q = 2:numel(taus)
        text(taus(q) * 1e3 * 1.15, ripple(q) * 1.15, sprintf('%.2f kJ', E_buf(q) / 1e3), 'FontSize', 7, ...
            'HorizontalAlignment', 'left', 'Color', cc.ink2);
    end
    set(gca, 'YScale', 'log');
    xlabel('Buffer time constant tau (ms)'); ylabel('Bus ripple amplitude (V)');
    title(sprintf('Ripple vs buffer size (labels: energy the buffer swings). Need %.1f kJ', E_req / 1e3), 'FontSize', 9);
    legend({'Bus ripple', 'MIL-STD-704F limit 6 V'}, 'Location', 'southwest', 'FontSize', 8);
    grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_pulsed_radar.png'));
end
end
