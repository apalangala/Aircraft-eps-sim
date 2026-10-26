function [cap_cont, cap_ovl, th] = generator_step(g, th, P_out, dt)
%GENERATOR_STEP  Thermal overload model of a generator (main or APU).
%
%   [cap_cont, cap_ovl, th] = GENERATOR_STEP(g, th, P_out, dt)
%
%   th is a normalised thermal state that follows (P/P_rated)^2 with time
%   constant g.tau_th, so th = 1 means "running at rated power for a long
%   time". While th < g.th_max the generator can deliver g.ovl_factor times
%   its rating for a short time; once th reaches g.th_max only the
%   continuous rating is available until it cools down.
%
%   Outputs:
%     cap_cont - continuous capacity [W] (what load shedding aims for)
%     cap_ovl  - capacity available right now including overload [W]
%     th       - updated thermal state

x = (P_out / g.P_rated)^2;
a = exp(-dt / g.tau_th);
th = a * th + (1 - a) * x;

cap_cont = g.P_rated;
if th < g.th_max
    cap_ovl = g.ovl_factor * g.P_rated;
else
    cap_ovl = g.P_rated;
end
end
