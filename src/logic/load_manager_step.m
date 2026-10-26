function [lm, pf, C, deficit] = load_manager_step(p, L, lm, P_full, bm, h, caps, P_charge, dt, info)
%LOAD_MANAGER_STEP  Priority load shedding and sequenced restoration.
%
%   Shedding
%     - A constraint (generator, APU, battery, DC/DC group, inverter) that
%       is above its continuous rating for longer than p.shed.delay, or
%       above its short-time overload capability at any instant, triggers
%       shedding.
%     - Loads on that constraint are stepped down one level at a time,
%       highest rank first (rank = shed order), until usage is at or below
%       p.shed.margin x continuous rating.
%     - Priority-1 (flight-critical) loads are never shed.
%     - When a bus loses power, its sheddable loads are marked shed so they
%       come back one at a time instead of all at once (no inrush pile-up).
%     - On battery only, every load that is not priority 1 is shed to save
%       energy (p.shed.battery_essential_only).
%
%   Restoration
%     - Only when no constraint is over its continuous rating.
%     - The most important shed load (lowest prio, then lowest rank) that
%       fits with hysteresis margin is the candidate. It must keep fitting
%       for p.shed.restore_delay before it is stepped up one level. This
%       hysteresis is what stops loads chattering on and off at the limit.
%
%   deficit is true if a constraint is still over its overload capability
%   with every sheddable load already off, i.e. flight-critical demand
%   exceeds what the source can give.

if nargin < 10 || isempty(info)
    info = load_info(L);
end
prio = info.prio;
rank = info.rank;
nlev = info.nlev;
deficit = false;

% --- dead-bus shedding ---------------------------------------------------
pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), P_charge, info);
went_dead = lm.prev_live & ~pf.bus_live;
changed = false;
for k = find(went_dead & prio > 1 & lm.lvl < nlev)
    lm.lvl(k) = nlev(k);
    lm.n_shed_events(k) = lm.n_shed_events(k) + 1;
    changed = true;
end
lm.prev_live = pf.bus_live;

% --- battery-only energy conservation ------------------------------------
on_batt = strcmp(bm.feed_HVE, 'BATT') & (info.isHVE | info.isLV);
if p.shed.battery_essential_only
    for k = find(on_batt & prio > 1 & lm.lvl < nlev)
        lm.lvl(k) = nlev(k);
        lm.n_shed_events(k) = lm.n_shed_events(k) + 1;
        changed = true;
    end
end

if changed
    pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), P_charge, info);
end
C = eval_constraints(p, pf, caps);

% --- overload detection and shedding -------------------------------------
any_shed = false;
for c = 1:numel(C)
    nm = C(c).name;
    if C(c).usage > C(c).cap_cont + 1e-6
        lm.over_timer.(nm) = lm.over_timer.(nm) + dt;
    else
        lm.over_timer.(nm) = 0;
    end
    trigger = C(c).usage > C(c).cap_ovl + 1e-6 || lm.over_timer.(nm) >= p.shed.delay - 1e-9;
    if ~trigger
        continue
    end
    target = p.shed.margin * C(c).cap_cont;
    usage = C(c).usage;
    while usage > target
        cand = find(C(c).member & prio > 1 & lm.lvl < nlev & P_full > 0);
        if isempty(cand)
            break
        end
        [~, j] = max(rank(cand));
        k = cand(j);
        lm.lvl(k) = lm.lvl(k) + 1;
        lm.n_shed_events(k) = lm.n_shed_events(k) + 1;
        any_shed = true;
        pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), P_charge, info);
        Cn = eval_constraints(p, pf, caps);
        idx = find(strcmp({Cn.name}, nm), 1);
        usage = Cn(idx).usage;
    end
    lm.over_timer.(nm) = 0;
end

if any_shed
    C = eval_constraints(p, pf, caps);
    lm.restore_timer = 0;
    lm.restore_cand = 0;
end

% flight-critical demand above what the source can deliver
any_over = false;
for c = 1:numel(C)
    if C(c).usage > C(c).cap_ovl + 1e-6
        deficit = true;
    end
    if C(c).usage > C(c).cap_cont + 1e-6
        any_over = true;
    end
end

% --- restoration ---------------------------------------------------------
if any_over || any_shed
    lm.restore_timer = 0;
    lm.restore_cand = 0;
    return
end

shed = find(lm.lvl > 1 & pf.bus_live);
if p.shed.battery_essential_only
    shed = shed(~(on_batt(shed) & prio(shed) > 1));
end
if isempty(shed)
    lm.restore_timer = 0;
    lm.restore_cand = 0;
    return
end
% order: most important first (low prio), then reverse shed order (low rank)
[~, order] = sort(prio(shed) * 1000 + rank(shed));
shed = shed(order);
pick = 0;
for k = shed
    dP = P_full(k) * (info.levmat(k, lm.lvl(k) - 1) - info.levmat(k, lm.lvl(k)));
    fits = true;
    for c = 1:numel(C)
        if C(c).member(k)
            need = C(c).usage + C(c).gain(k) * dP * (1 + p.shed.restore_frac) + p.shed.restore_abs;
            if need > p.shed.margin * C(c).cap_cont
                fits = false;
                break
            end
        end
    end
    if fits
        pick = k;
        break
    end
end

if pick == 0
    lm.restore_timer = 0;
    lm.restore_cand = 0;
    return
end
if pick ~= lm.restore_cand
    lm.restore_cand = pick;
    lm.restore_timer = 0;
end
lm.restore_timer = lm.restore_timer + dt;
if lm.restore_timer >= p.shed.restore_delay - 1e-9
    lm.lvl(pick) = lm.lvl(pick) - 1;
    lm.n_restore_events(pick) = lm.n_restore_events(pick) + 1;
    lm.restore_timer = 0;
    lm.restore_cand = 0;
    pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), P_charge, info);
    C = eval_constraints(p, pf, caps);
end
end
