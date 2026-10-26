function L = load_table()
%LOAD_TABLE  Electrical load list with priorities and per-phase demand.
%
%   L(k) fields:
%     name    - load name
%     bus     - 'HV1' | 'HV2' | 'HVE' (270 V essential) | 'LV' (28 V) | 'AC' (115 V 400 Hz)
%     prio    - 1 flight-critical (never shed), 2 mission, 3 non-essential
%     rank    - shed order inside the load list: higher rank is shed first
%     levels  - allowed power levels as fractions of demand, highest first.
%               [1 0] = on/off. [1 0.5 0] = can drop to a 50 % mode first.
%     demand  - [kW] demand in each mission phase (see mission_profile.m):
%               TAXI TAKEOFF CLIMB CRUISE MISSION RTB APPROACH
%
%   The numbers are engineering assumptions for a generic twin-engine
%   military UAV. They are chosen to be plausible in order of magnitude,
%   not to describe any real aircraft. See docs/assumptions.md.
%
%   ECS mission demand follows ECS = 8 kW + 0.4 x radar power, because the
%   radar's waste heat has to be removed. studies/study_radar_headroom.m
%   uses the same rule.

%            name                          bus    prio rank levels      TAXI TKOF CLMB CRUS MISN RTB  APPR
rows = { ...
    'Flight control actuators',          'HVE', 1,  0, [1 0],     [1.5  10   5    3    5    3    10 ]; ...
    'Fuel pumps',                        'HVE', 1,  0, [1 0],     [3    6    6    5    5    5    4  ]; ...
    'Landing gear & brakes',             'HVE', 1,  0, [1 0],     [1    6    0    0    0    0    6  ]; ...
    'Flight computers & avionics',       'LV',  1,  0, [1 0],     [2.5  2.5  2.5  2.5  2.5  2.5  2.5]; ...
    'C2 datalink',                       'LV',  1,  0, [1 0],     [1    1    1    1    1    1    1  ]; ...
    'Engine control (FADEC)',            'LV',  1,  0, [1 0],     [0.5  0.5  0.5  0.5  0.5  0.5  0.5]; ...
    'AESA radar',                        'HV2', 2,  7, [1 0.5 0], [0    0    0    5    25   5    0  ]; ...
    'ECS / liquid cooling',              'HV1', 2,  5, [1 0],     [8    10   12   10   18   10   10 ]; ...
    'Mission SATCOM',                    'LV',  2,  8, [1 0],     [0.5  1    1    1    2    1    1  ]; ...
    'EO/IR turret',                      'AC',  2,  9, [1 0],     [0    0    0    1    3    1    0  ]; ...
    'Ice protection',                    'AC',  3,  10,[1 0],     [0    4    4    2    2    2    4  ]; ...
    'Bay heaters & utility',             'HV1', 3,  11,[1 0],     [3    2    2    2    2    2    3  ]; ...
    'Payload bay (non-essential)',       'HV2', 3,  12,[1 0],     [2    2    3    4    4    3    2  ]; ...
    'Lighting',                          'LV',  3,  13,[1 0],     [0.8  0.8  0.5  0.3  0.3  0.3  0.8]};

n = size(rows, 1);
L = struct('name', cell(1, n), 'bus', [], 'prio', [], 'rank', [], 'levels', [], 'demand', []);
for k = 1:n
    L(k).name   = rows{k, 1};
    L(k).bus    = rows{k, 2};
    L(k).prio   = rows{k, 3};
    L(k).rank   = rows{k, 4};
    L(k).levels = rows{k, 5};
    L(k).demand = rows{k, 6} * 1e3;   % kW -> W
end
end
