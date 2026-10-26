function m = mission_profile()
%MISSION_PROFILE  Flight phases, durations and altitude for the reference mission.
%
%   m.names     - phase names (match the columns of load_table.m)
%   m.dur_s     - phase durations [s]
%   m.alt_start - altitude at phase start [ft] (for plots only)
%   m.alt_end   - altitude at phase end [ft]

m.names     = {'TAXI', 'TAKEOFF', 'CLIMB', 'CRUISE', 'MISSION', 'RTB', 'APPROACH'};
m.dur_s     = [6 2 8 15 35 15 7] * 60;
m.alt_start = [0 0    1000  25000 25000 25000 25000];
m.alt_end   = [0 1000 25000 25000 25000 25000 0];
m.t_start   = [0 cumsum(m.dur_s(1:end-1))];
m.t_end     = cumsum(m.dur_s);
m.T_total   = m.t_end(end);
end
