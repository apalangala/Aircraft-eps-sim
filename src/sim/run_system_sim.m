function out = run_system_sim(sc, p, L, m)
%RUN_SYSTEM_SIM  Run one mission scenario through the system-level model.
%
%   out = RUN_SYSTEM_SIM(sc) uses the baseline parameters, load table and
%   mission. out = RUN_SYSTEM_SIM(sc, p, L, m) uses the ones given.
%
%   sc (see scenarios/scenario_list.m):
%     sc.name, sc.title          identifiers
%     sc.events                  struct array with fields t [s], target, action
%                                target: 'GEN1' 'GEN2' 'APU' 'DCDC1' 'DCDC2' 'INV' 'BATT'
%                                action: 'fail' | 'recover'
%     sc.apu_start_fails         true if the in-flight APU start fails
%     sc.batt_T                  battery temperature [degC] (optional)
%     sc.t_end                   stop time [s] (optional, default end of mission)
%     sc.t_start                 start time [s] (optional, default 0). Used by the
%                                tests to start part-way through the mission.
%
%   Each step: fault injection -> APU sequencing -> bus manager ->
%   load manager (shedding / restoration) -> battery charging from spare
%   capacity -> source thermal and battery state update -> logging.

if nargin < 2 || isempty(p), p = eps_params(); end
if nargin < 3 || isempty(L), L = load_table(); end
if nargin < 4 || isempty(m), m = mission_profile(); end
if isfield(sc, 'batt_T') && ~isempty(sc.batt_T)
    p.batt.T_degC = sc.batt_T;
end
if ~isfield(sc, 'apu_start_fails'), sc.apu_start_fails = false; end
t_end = m.T_total;
if isfield(sc, 't_end') && ~isempty(sc.t_end), t_end = sc.t_end; end

t_start = 0;
if isfield(sc, 't_start') && ~isempty(sc.t_start), t_start = sc.t_start; end

dt = p.dt;
N = round((t_end - t_start) / dt);
n = numel(L);
info = load_info(L);
topo = eps_topology();
modes = {'NORMAL', 'GEN+APU', 'SINGLE_GEN', 'APU_ONLY', 'BATTERY_EMERGENCY', 'TOTAL_LOSS'};

% --- states --------------------------------------------------------------
h.gen_ok  = [true true];
h.dcdc_ok = [true true];
h.inv_ok  = true;
batt_failed = false;
apu_state = 0;            % 0 OFF, 1 STARTING, 2 RUNNING, 3 FAILED
apu_timer = 0;
apu_start_cmd_t = NaN;
apu_online_t = NaN;
th = [0.5 0.5 0];         % generator thermal states [GEN1 GEN2 APU], warm start
bs = battery_init(p.batt);
lm = load_manager_init(L);
P_src_prev = [0 0 0 0];
ev = sc.events;
ev_done = false(1, numel(ev));

% --- logs ----------------------------------------------------------------
lg.t = t_start + (0:N-1) * dt;
z = zeros(1, N);
lg.phase = z; lg.alt = z; lg.mode = z; lg.apu_state = z;
lg.P_src = zeros(4, N); lg.P_batt = z; lg.P_charge = z;
lg.soc = z; lg.v_cell = z; lg.batt_Pmax = z;
lg.V = zeros(5, N);       % HV1 HV2 HVE LV AC(115 if live else 0)
lg.P_full = zeros(n, N); lg.P_served = zeros(n, N);
lg.status = zeros(n, N);  % 2 full, 1 reduced, 0 shed, -1 bus dead
lg.closed = false(8, N);
lg.sources_per_island = z;   % max number of active sources sharing an island
lg.paralleled_gens = false(1, N);
lg.deficit = false(1, N);
lg.loss = z; lg.loss_bcru = z;
lg.th = zeros(3, N);
lg.cap = zeros(4, N);     % continuous capacity of each source (0 if offline)

for i = 1:N
    t = lg.t(i);
    [ph, alt] = mission_phase(m, t);

    % --- fault injection -------------------------------------------------
    for e = 1:numel(ev)
        if ~ev_done(e) && t >= ev(e).t - 1e-9
            ev_done(e) = true;
            ok = strcmp(ev(e).action, 'recover');
            switch ev(e).target
                case 'GEN1',  h.gen_ok(1) = ok;
                case 'GEN2',  h.gen_ok(2) = ok;
                case 'DCDC1', h.dcdc_ok(1) = ok;
                case 'DCDC2', h.dcdc_ok(2) = ok;
                case 'INV',   h.inv_ok = ok;
                case 'BATT',  batt_failed = ~ok;
                case 'APU'
                    if ~ok, apu_state = 3; end
                otherwise
                    error('run_system_sim:event', 'Unknown event target %s', ev(e).target);
            end
        end
    end

    % --- APU sequencing --------------------------------------------------
    need_apu = ~all(h.gen_ok);
    if need_apu && apu_state == 0
        apu_state = 1;
        apu_timer = 0;
        apu_start_cmd_t = t;
    elseif apu_state == 1
        apu_timer = apu_timer + dt;
        if apu_timer >= p.apu.start_time - 1e-9
            if sc.apu_start_fails
                apu_state = 3;
            else
                apu_state = 2;
                apu_online_t = t;
            end
        end
    end
    h.apu_ok = (apu_state == 2);
    h.batt_ok = ~batt_failed && ~bs.depleted;

    % --- bus manager -----------------------------------------------------
    bm = bus_manager(h);

    % --- source capacities ----------------------------------------------
    caps = struct();
    for g = 1:2
        [cc, co] = generator_step(p.gen(g), th(g), P_src_prev(g), 0);
        caps.(p.gen(g).name) = struct('cont', cc * h.gen_ok(g), 'ovl', co * h.gen_ok(g));
    end
    [cc, co] = generator_step(p.apu, th(3), P_src_prev(3), 0);
    caps.APU = struct('cont', cc * h.apu_ok, 'ovl', co * h.apu_ok);
    Pb = min(p.bcru.P_rated, battery_power_limit(p.batt, bs) * p.bcru.eta) * h.batt_ok;
    caps.BATT = struct('cont', Pb, 'ovl', Pb);

    % --- loads and load manager -----------------------------------------
    P_full = info.D(:, ph)';
    [lm, pf, C, deficit] = load_manager_step(p, L, lm, P_full, bm, h, caps, 0, dt, info);

    % --- battery charging from spare capacity ---------------------------
    P_charge = 0;
    if strcmp(bm.bcru_mode, 'CHARGE') && bs.soc < p.batt.soc_target
        idx = find(strcmp({C.name}, bm.feed_HVE), 1);
        if ~isempty(idx)
            head = p.shed.margin * C(idx).cap_cont - C(idx).usage;
            P_charge = min(p.batt.P_charge_max, max(0, head));
        end
    end
    if P_charge > 0
        pf = power_flow(p, L, bm, h, P_full, level_frac(info, lm.lvl), P_charge, info);
    end

    % --- source and battery states ---------------------------------------
    for g = 1:2
        [~, ~, th(g)] = generator_step(p.gen(g), th(g), pf.P_src(g), dt);
    end
    [~, ~, th(3)] = generator_step(p.apu, th(3), pf.P_src(3), dt);
    [bs, P_act] = battery_step(p.batt, bs, pf.P_batt, dt);
    if pf.P_batt > 0 && P_act == 0
        deficit = true;           % battery cut off while carrying the bus
    end
    P_src_prev = pf.P_src;

    % --- bus voltages (steady state) -------------------------------------
    V = zeros(1, 5);
    src_names = {'GEN1', 'GEN2', 'APU', 'BATT'};
    Vsrc = zeros(1, 4);
    for s = 1:3
        I = pf.P_src(s) / p.V_hv;
        Vsrc(s) = p.V_hv - p.R_feeder_hv * I;
    end
    Vsrc(4) = p.V_hv - p.R_droop_bcru * pf.P_src(4) / p.V_hv;
    % crude sag when a source is beyond what it can deliver
    for c = 1:numel(C)
        s = find(strcmp(src_names, C(c).name), 1);
        if ~isempty(s) && C(c).usage > C(c).cap_ovl + 1e-6
            Vsrc(s) = Vsrc(s) * max(C(c).cap_ovl, 0) / C(c).usage;
        end
    end
    if pf.P_batt > 0 && P_act == 0
        Vsrc(4) = 0;
    end
    feeds = {bm.feed_HV1, bm.feed_HV2};
    for b = 1:2
        s = find(strcmp(src_names, feeds{b}), 1);
        if ~isempty(s), V(b) = Vsrc(s); end
    end
    if strcmp(bm.feed_HVE, 'BATT')
        V(3) = Vsrc(4);
    elseif ~strcmp(bm.feed_HVE, 'NONE')
        Vpar = V(1);
        if ~bm.closed(6), Vpar = V(2); end
        V(3) = Vpar - p.R_feeder_ess * pf.draw.HVE / max(Vpar, 1);
    end
    if pf.live.LV && V(3) > 0
        V(4) = p.V_lv - p.R_droop_lv * (pf.LV_out / p.V_lv) / max(pf.n_dcdc, 1);
        if V(3) < 200, V(4) = V(4) * V(3) / 200; end   % converter drops out of regulation
    end
    V(5) = 115 * pf.live.AC;

    % --- interlock bookkeeping -------------------------------------------
    comp = connected_components(numel(topo.nodes), topo.edges, bm.closed);
    active_src = [h.gen_ok(1) && bm.closed(1), h.gen_ok(2) && bm.closed(2), ...
                  h.apu_ok && bm.closed(3), bm.closed(8)];
    ncount = 0;
    for cid = unique(comp)
        ncount = max(ncount, sum(active_src & comp(1:4) == cid));
    end

    % --- log -------------------------------------------------------------
    lg.phase(i) = ph; lg.alt(i) = alt;
    lg.mode(i) = find(strcmp(modes, bm.mode));
    lg.apu_state(i) = apu_state;
    lg.P_src(:, i) = pf.P_src(:);
    lg.P_batt(i) = P_act * (pf.P_batt > 0) + pf.P_batt * (pf.P_batt <= 0);
    lg.P_charge(i) = pf.P_charge;
    lg.soc(i) = bs.soc; lg.v_cell(i) = bs.v_cell;
    lg.batt_Pmax(i) = Pb;
    lg.V(:, i) = V(:);
    lg.P_full(:, i) = P_full(:);
    lg.P_served(:, i) = pf.P_served(:);
    fr = level_frac(info, lm.lvl);
    st = 2 * (fr >= 1) + 1 * (fr > 0 & fr < 1);
    st(~pf.bus_live) = -1;
    lg.status(:, i) = st(:);
    lg.closed(:, i) = bm.closed(:);
    lg.sources_per_island(i) = ncount;
    lg.paralleled_gens(i) = bm.closed(1) && bm.closed(2) && comp(1) == comp(2);
    lg.deficit(i) = deficit;
    lg.loss(i) = pf.loss.dcdc + pf.loss.inv;      % losses on the bus side
    lg.loss_bcru(i) = pf.loss.bcru;
    lg.th(:, i) = th(:);
    lg.cap(:, i) = [caps.GEN1.cont; caps.GEN2.cont; caps.APU.cont; caps.BATT.cont];
end

out.sc = sc;
out.p = p;
out.L = L;
out.m = m;
out.log = lg;
out.modes = modes;
out.lm = lm;
out.apu_start_cmd_t = apu_start_cmd_t;
out.apu_online_t = apu_online_t;
out.batt_depleted = bs.depleted;
out.summary = summarize_run(out);
end
