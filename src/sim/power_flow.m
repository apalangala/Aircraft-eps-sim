function pf = power_flow(p, L, bm, h, P_full, frac, P_charge, info)
%POWER_FLOW  Quasi-static power flow for one time step.
%
%   pf = POWER_FLOW(p, L, bm, h, P_full, frac, P_charge, info)
%
%   p, L    - parameters and load table
%   bm      - bus manager output (which source feeds each bus)
%   h       - health struct (dcdc_ok, inv_ok)
%   P_full  - 1xN full demand of each load this phase [W]
%   frac    - 1xN power level of each load (1 = full, 0 = shed)
%   P_charge - power drawn from the essential bus to charge the battery [W]
%   info    - optional, load_info(L) (pass it in loops for speed)
%
%   Converter losses are included, so the sum of source outputs equals the
%   sum of served loads plus losses plus battery charging (checked by
%   tests/test_energy_balance.m).

if nargin < 8 || isempty(info)
    info = load_info(L);
end
n = info.n;
src = {'GEN1', 'GEN2', 'APU', 'BATT'};

% source index feeding each bus (0 = dead)
f1 = src_index(bm.feed_HV1);
f2 = src_index(bm.feed_HV2);
fE = src_index(bm.feed_HVE);

live.HV1 = f1 > 0;
live.HV2 = f2 > 0;
live.HVE = fE > 0;
n_dcdc = sum(double(h.dcdc_ok(:)'));
live.LV  = live.HVE && n_dcdc > 0;
live.AC  = live.HV2 && logical(h.inv_ok);

bus_live = (info.isHV1 & live.HV1) | (info.isHV2 & live.HV2) | ...
           (info.isHVE & live.HVE) | (info.isLV & live.LV) | (info.isAC & live.AC);

P_served = P_full .* frac .* bus_live;

% --- 28 V bus through the DC/DC converters (equal current sharing) -------
LV_out = sum(P_served(info.isLV));
dcdc_out = zeros(1, 2);
dcdc_loss = zeros(1, 2);
if live.LV
    for c = 1:2
        if h.dcdc_ok(c)
            dcdc_out(c) = LV_out / n_dcdc;
            dcdc_loss(c) = conv_loss(dcdc_out(c), p.dcdc(c).P_rated, ...
                p.dcdc(c).eta, p.conv_noload_frac, true);
        end
    end
end
LV_in = LV_out + sum(dcdc_loss);

% --- 115 V AC bus through the inverter -----------------------------------
AC_out = sum(P_served(info.isAC));
inv_loss = conv_loss(AC_out, p.inv.P_rated, p.inv.eta, p.conv_noload_frac, live.AC);
AC_in = (AC_out + inv_loss) * live.AC;

% --- bus draws -----------------------------------------------------------
if ~live.HVE
    P_charge = 0;
end
draw.HV1 = sum(P_served(info.isHV1));
draw.HV2 = sum(P_served(info.isHV2)) + AC_in;
draw.HVE = sum(P_served(info.isHVE)) + LV_in + P_charge;

% --- source outputs ------------------------------------------------------
P_src = zeros(1, 4);
if f1 > 0, P_src(f1) = P_src(f1) + draw.HV1; end
if f2 > 0, P_src(f2) = P_src(f2) + draw.HV2; end
if fE > 0, P_src(fE) = P_src(fE) + draw.HVE; end

% --- battery converter ---------------------------------------------------
if fE == 4
    bcru_loss = conv_loss(P_src(4), p.bcru.P_rated, p.bcru.eta, p.conv_noload_frac, true);
    P_batt = P_src(4) + bcru_loss;              % + = discharge
elseif P_charge > 0
    bcru_loss = conv_loss(P_charge, p.bcru.P_rated, p.bcru.eta, p.conv_noload_frac, true);
    P_batt = -(P_charge - bcru_loss);           % - = charge
else
    bcru_loss = 0;
    P_batt = 0;
end

% --- which source each load hangs off, and its marginal factor ----------
load_src_idx = f1 * info.isHV1 + f2 * info.isHV2 + fE * (info.isHVE | info.isLV) + f2 * info.isAC;
gain = ones(1, n);
gain(info.isLV) = 1 / p.dcdc(1).eta;
gain(info.isAC) = 1 / p.inv.eta;

pf.live = live;
pf.bus_live = bus_live;
pf.P_served = P_served;
pf.P_src = P_src;                 % [GEN1 GEN2 APU BATT(BCRU output)]
pf.P_batt = P_batt;               % battery terminal power, + = discharge
pf.P_charge = P_charge;
pf.draw = draw;
pf.LV_out = LV_out;
pf.AC_out = AC_out;
pf.dcdc_out = dcdc_out;
pf.n_dcdc = n_dcdc;
pf.loss = struct('dcdc', sum(dcdc_loss), 'inv', inv_loss, 'bcru', bcru_loss);
pf.load_src_idx = load_src_idx;   % 0 = dead, 1..4 = GEN1 GEN2 APU BATT
pf.gain = gain;
pf.isLV = info.isLV;
pf.isAC = info.isAC;
pf.src_names = src;
end

function k = src_index(name)
switch name
    case 'GEN1', k = 1;
    case 'GEN2', k = 2;
    case 'APU',  k = 3;
    case 'BATT', k = 4;
    otherwise,   k = 0;
end
end
