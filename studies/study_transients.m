function res = study_transients(tp, figdir)
%STUDY_TRANSIENTS  270 V bus transients checked against MIL-STD-704F.
%
%   Events on one 60 kW generator channel, with a 10 kW radar power supply
%   (damped input filter) on the bus throughout:
%     1. Load application: resistive load steps from 5 kW to 50 kW
%        (bus total 15 -> 60 kW, i.e. 25 % -> 100 % of rating).
%     2. Load rejection: 50 kW -> 5 kW (the worst case for overvoltage).
%     3. Bus transfer: the generator is lost and another, already running
%        source picks the bus up after a 30 ms detection + contactor
%        transfer time. During the gap the bus collapses; MIL-STD-704F
%        allows an interruption of up to 50 ms. The interruption is timed
%        from source loss until the voltage is back above 250 V; after that
%        the recovery must stay inside the normal transient envelope.
%        Run twice: (a) the incoming source regulates straight to 270 V,
%        (b) its voltage reference ramps up over 8 ms (soft start).
%        (The essential bus HVE never sees this gap: the battery converter
%        is always connected and takes over without a break.)

if nargin < 1 || isempty(tp), tp = transient_params(); end
if nargin < 2, figdir = ''; end
tp.damp = true;
lim = mil704_limits();
V = tp.Vref;
P_cpl = 10e3;
t0 = 0.05;

% ---- 1. load application ----------------------------------------------
inp = @(t) struct('G', (5e3 + 45e3 * (t >= t0)) / V^2, 'P', P_cpl, 'connected', true);
r1 = simulate_hvdc(tp, 0.35, inp);
c1 = check_transient_envelope(r1.t, r1.v, t0, lim.hv);

% ---- 2. load rejection --------------------------------------------------
inp = @(t) struct('G', (50e3 - 45e3 * (t >= t0)) / V^2, 'P', P_cpl, 'connected', true);
r2 = simulate_hvdc(tp, 0.35, inp);
c2 = check_transient_envelope(r2.t, r2.v, t0, lim.hv);

% ---- 3. bus transfer, without and with soft start -----------------------
t_tr = 0.030;            % [s] detection + contactor transfer time
t_ramp = 0.008;          % [s] soft-start reference ramp
if isfield(tp, 't_ramp'), t_ramp = tp.t_ramp; end
[r3a, c3a] = run_transfer(tp, lim, t0, t_tr, P_cpl, 0);
[r3b, c3b] = run_transfer(tp, lim, t0, t_tr, P_cpl, t_ramp);

strip = @(c) rmfield(c, {'env_t', 'env_up', 'env_lo'});
res.application = strip(c1);
res.rejection = strip(c2);
res.transfer_hard = strip(c3a);
res.transfer_soft = strip(c3b);
res.transfer_time_s = t_tr;
res.soft_start_ramp_s = t_ramp;

if ~isempty(figdir)
    cc = eps_colors();
    fig = figure('Visible', 'off', 'Position', [50 50 1250 430], 'Color', 'w');
    R = {r1, r2};
    C = {c1, c2};
    ttl = {'Load application 15 -> 60 kW', 'Load rejection 60 -> 15 kW'};
    for k = 1:2
        subplot(1, 3, k); hold on
        ms = (R{k}.t - t0) * 1e3;
        envt = C{k}.env_t * 1e3;
        sel = envt <= 250;
        plot(envt(sel), C{k}.env_up(sel), '-', 'Color', cc.crit, 'LineWidth', 1.2);
        plot(envt(sel), C{k}.env_lo(sel), '-', 'Color', cc.crit, 'LineWidth', 1.2, 'HandleVisibility', 'off');
        plot(ms, R{k}.v, '-', 'Color', cc.s1, 'LineWidth', 1.8);
        xlim([-20 200]); ylim([180 385]);
        title(sprintf('%s  [%s]', ttl{k}, verdict(C{k}.pass)), 'FontSize', 9);
        xlabel('Time from event (ms)');
        if k == 1, ylabel('270 V bus voltage (V)'); end
        legend({'MIL-STD-704F normal transient limits', 'Bus voltage'}, 'Location', 'northeast', 'FontSize', 7);
        grid on; box on;
    end
    subplot(1, 3, 3); hold on
    % envelope drawn from the soft-start recovery instant
    envt = c3b.env_t * 1e3 + c3b.interruption_s * 1e3;
    sel = envt <= 250;
    plot(envt(sel), c3b.env_up(sel), '-', 'Color', cc.crit, 'LineWidth', 1.2);
    plot(envt(sel), c3b.env_lo(sel), '-', 'Color', cc.crit, 'LineWidth', 1.2, 'HandleVisibility', 'off');
    plot((r3a.t - t0) * 1e3, r3a.v, '-', 'Color', cc.s2, 'LineWidth', 1.6);
    plot((r3b.t - t0) * 1e3, r3b.v, '-', 'Color', cc.s1, 'LineWidth', 1.8);
    plot(50 * [1 1], [0 360], ':', 'Color', cc.ink2, 'HandleVisibility', 'off');
    text(51, 345, '50 ms interruption limit', 'FontSize', 7, 'Color', cc.ink2);
    xlim([-10 200]); ylim([0 360]);
    title(sprintf('Bus transfer, %.0f ms gap: hard [%s], soft start [%s]', t_tr * 1e3, ...
        verdict(c3a.pass), verdict(c3b.pass)), 'FontSize', 9);
    xlabel('Time from source loss (ms)');
    legend({'Normal transient limits (from recovery, soft start)', ...
        sprintf('No soft start (peak %.0f V)', c3a.v_max), ...
        sprintf('8 ms soft start (peak %.0f V)', c3b.v_max)}, 'Location', 'southeast', 'FontSize', 7);
    grid on; box on;
    save_fig(fig, fullfile(figdir, 'study_transients.png'));
end
end

function [r, c] = run_transfer(tp, lim, t0, t_tr, P_cpl, t_ramp)
G = 30e3 / tp.Vref^2;
inp = @(t) struct('G', G, 'P', P_cpl, 'connected', t < t0);
ra = simulate_hvdc(tp, t0 + t_tr, inp);
xb = ra.x;
xb(1) = 0;
v_now = xb(2);
if t_ramp > 0
    % incoming source starts from the present bus voltage and ramps up
    xb(5) = 0; xb(6) = v_now;
    inp = @(t) struct('G', G, 'P', P_cpl, 'connected', true, ...
        'Vref', v_now + (tp.Vref - v_now) * min(t / t_ramp, 1));
else
    % incoming source already regulating at 270 V
    xb(5) = 0; xb(6) = tp.Vref;
    inp = @(t) struct('G', G, 'P', P_cpl, 'connected', true);
end
rb = simulate_hvdc(tp, 0.3, inp, xb);
r.t = [ra.t, rb.t(2:end) + ra.t(end)];
r.v = [ra.v, rb.v(2:end)];
k_back = find(r.t > t0 + t_tr & r.v >= lim.hv.ss_min, 1, 'first');
t_re = r.t(k_back);
c = check_transient_envelope(r.t, r.v, t_re, lim.hv);
c.interruption_s = t_re - t0;
c.interruption_ok = c.interruption_s <= lim.transfer_interrupt_max;
c.envelope_ok = c.pass;
c.pass = c.envelope_ok && c.interruption_ok;
end

function s = verdict(ok)
if ok
    s = 'PASS';
else
    s = 'FAIL';
end
end
