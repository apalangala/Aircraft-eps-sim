function r = simulate_hvdc(tp, t_end, inputs, x0)
%SIMULATE_HVDC  Fixed-step RK4 simulation of the averaged 270 V DC channel.
%
%   r = SIMULATE_HVDC(tp, t_end, inputs, x0)
%     inputs(t) takes a ROW VECTOR of times and returns a struct with
%     row-vector fields G (load conductance [S]), P (constant-power load
%     [W]) and connected (logical), and optionally Vref (regulator
%     set-point [V]). It is evaluated once for the whole run.
%     x0 is the initial state (default: equilibrium for inputs(0)).
%
%   r.t, r.v (bus voltage), r.v_cf (radar-PSU filter voltage), r.i_s
%   (source current), r.E (generator EMF), r.P, r.G, r.x (final state).

dt = tp.dt;
N = round(t_end / dt) + 1;
r.t = (0:N-1) * dt;
U = inputs(r.t);
G = U.G .* ones(1, N);
P = U.P .* ones(1, N);
con = logical(U.connected .* ones(1, N));
if isfield(U, 'Vref')
    Vr = U.Vref .* ones(1, N);
else
    Vr = tp.Vref * ones(1, N);
end
if nargin < 4 || isempty(x0)
    x0 = hvdc_equilibrium(tp, G(1), P(1));
end
x = x0(:);

r.v = zeros(1, N); r.v_cf = zeros(1, N); r.i_s = zeros(1, N);
r.E = zeros(1, N); r.P = P; r.G = G;

for k = 1:N
    r.v(k) = x(2); r.v_cf(k) = x(4); r.i_s(k) = x(1); r.E(k) = x(6);
    g = G(k); pk = P(k); ck = con(k); vr = Vr(k);
    if k == N
        break
    end
    % inputs held constant over the step (zero-order hold)
    k1 = hvdc_rhs(tp, x, g, pk, ck, vr);
    k2 = hvdc_rhs(tp, x + 0.5 * dt * k1, g, pk, ck, vr);
    k3 = hvdc_rhs(tp, x + 0.5 * dt * k2, g, pk, ck, vr);
    k4 = hvdc_rhs(tp, x + dt * k3, g, pk, ck, vr);
    x = x + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4);
    % rectifier blocks reverse current; open contactor carries none;
    % the generator control unit limits fault / inrush current
    if ~ck || x(1) < 0
        x(1) = 0;
    elseif x(1) > tp.I_lim
        x(1) = tp.I_lim;
    end
    x(6) = min(max(x(6), tp.E_min), tp.E_max);
end
r.x = x;
end
