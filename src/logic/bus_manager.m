function bm = bus_manager(h)
%BUS_MANAGER  Bus power control logic: source health in, contactor states out.
%
%   bm = BUS_MANAGER(h) where h has logical fields
%     gen_ok   (1x2) main generators healthy and online
%     apu_ok         APU generator running and healthy
%     batt_ok        battery available (not failed, not cut off by the BMS)
%
%   This is the state machine you would put in Stateflow. It is written as
%   a pure function of source health so every combination can be tested
%   exhaustively (tests/test_bus_logic_truth_table.m). Timing (APU start
%   delay, shedding delays) lives in the simulator, not here.
%
%   Rules, in order:
%     1. Each generator feeds its own main bus (GLC closed when healthy).
%     2. Two generators are NEVER paralleled: a bus tie only closes to
%        carry one source onto the other side.
%     3. A lost side is picked up by the APU if it is online, otherwise by
%        the remaining generator through the tie.
%     4. The essential bus HVE is fed from HV1 if HV1 is powered, otherwise
%        from HV2. Only one feed is ever closed (no paralleling through HVE).
%     5. If neither main bus is powered, the battery converter (BCRU)
%        switches to discharge and holds HVE up on its own.
%
%   Outputs:
%     bm.closed    1x8 logical, contactor order from eps_topology()
%     bm.feed_HV1, bm.feed_HV2, bm.feed_HVE  source name or 'NONE'
%     bm.mode      'NORMAL' | 'GEN+APU' | 'SINGLE_GEN' | 'APU_ONLY' |
%                  'BATTERY_EMERGENCY' | 'TOTAL_LOSS'
%     bm.bcru_mode 'DISCHARGE' | 'CHARGE' (charging allowed) | 'OFF'
%     bm.apu_start_request  true when a generator is lost

g1 = logical(h.gen_ok(1));
g2 = logical(h.gen_ok(2));
apu = logical(h.apu_ok);

% --- decide which source feeds each side --------------------------------
if g1
    s1 = 'GEN1';
elseif apu
    s1 = 'APU';
elseif g2
    s1 = 'GEN2';
else
    s1 = 'NONE';
end

if g2
    s2 = 'GEN2';
elseif apu
    s2 = 'APU';
elseif g1
    s2 = 'GEN1';
else
    s2 = 'NONE';
end

% --- contactors ----------------------------------------------------------
% order: GLC1 GLC2 ALC BTC1 BTC2 EFC1 EFC2 BLC
GLC1 = g1;
GLC2 = g2;
ALC  = strcmp(s1, 'APU') || strcmp(s2, 'APU');
% a tie closes when its side is fed through the tie, or when its own
% generator is carrying the other side through the tie
BTC1 = any(strcmp(s1, {'APU', 'GEN2'})) || strcmp(s2, 'GEN1');
BTC2 = any(strcmp(s2, {'APU', 'GEN1'})) || strcmp(s1, 'GEN2');

hv1_live = ~strcmp(s1, 'NONE');
hv2_live = ~strcmp(s2, 'NONE');
EFC1 = hv1_live;
EFC2 = ~hv1_live && hv2_live;
BLC  = ~hv1_live && ~hv2_live && logical(h.batt_ok);

bm.closed = logical([GLC1 GLC2 ALC BTC1 BTC2 EFC1 EFC2 BLC]);
bm.feed_HV1 = s1;
bm.feed_HV2 = s2;
if EFC1
    bm.feed_HVE = s1;
elseif EFC2
    bm.feed_HVE = s2;
elseif BLC
    bm.feed_HVE = 'BATT';
else
    bm.feed_HVE = 'NONE';
end

% --- mode label and battery converter mode -------------------------------
if g1 && g2
    bm.mode = 'NORMAL';
elseif (g1 || g2) && apu
    bm.mode = 'GEN+APU';
elseif g1 || g2
    bm.mode = 'SINGLE_GEN';
elseif apu
    bm.mode = 'APU_ONLY';
elseif h.batt_ok
    bm.mode = 'BATTERY_EMERGENCY';
else
    bm.mode = 'TOTAL_LOSS';
end

if BLC
    bm.bcru_mode = 'DISCHARGE';
elseif ~strcmp(bm.feed_HVE, 'NONE') && h.batt_ok
    bm.bcru_mode = 'CHARGE';
else
    bm.bcru_mode = 'OFF';
end

bm.apu_start_request = ~(g1 && g2);
end
