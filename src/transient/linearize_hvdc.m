function [A, x0] = linearize_hvdc(tp, G_load, P_cpl)
%LINEARIZE_HVDC  Small-signal state matrix of the averaged 270 V DC channel.
%
%   [A, x0] = LINEARIZE_HVDC(tp, G_load, P_cpl) returns the Jacobian of
%   hvdc_rhs at the operating point (central differences). The eigenvalues
%   of A say whether the bus is small-signal stable: any eigenvalue with a
%   positive real part means it will oscillate and grow.
%   If the damping branch is not fitted its state is removed.

x0 = hvdc_equilibrium(tp, G_load, P_cpl);
n = numel(x0);
A = zeros(n);
for j = 1:n
    h = 1e-6 * max(1, abs(x0(j)));
    xp = x0; xp(j) = xp(j) + h;
    xm = x0; xm(j) = xm(j) - h;
    A(:, j) = (rhs_lin(tp, xp, G_load, P_cpl) - rhs_lin(tp, xm, G_load, P_cpl)) / (2 * h);
end
if ~tp.damp
    A = A(1:6, 1:6);
    x0 = x0(1:6);
end
end

function dx = rhs_lin(tp, x, G, P)
% same equations without the limiters (they are inactive at the operating point)
tp.E_max = inf;
tp.E_min = -inf;
dx = hvdc_rhs(tp, x, G, P, true);
end
