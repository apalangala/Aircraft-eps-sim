function [ph, alt] = mission_phase(m, t)
%MISSION_PHASE  Phase index and altitude [ft] at time t [s].
ph = find(t < m.t_end, 1, 'first');
if isempty(ph)
    ph = numel(m.t_end);
end
frac = (t - m.t_start(ph)) / m.dur_s(ph);
frac = min(max(frac, 0), 1);
alt = m.alt_start(ph) + frac * (m.alt_end(ph) - m.alt_start(ph));
end
