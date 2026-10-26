function [bs, P_actual, V_pack] = battery_step(b, bs, P_req, dt)
%BATTERY_STEP  Advance the Li-ion pack model by one time step.
%
%   [bs, P_actual, V_pack] = BATTERY_STEP(b, bs, P_req, dt)
%
%   Equivalent-circuit cell model (Thevenin, one RC branch):
%       v_cell = OCV(SOC) - v1 - i*R0
%       dv1/dt = -v1/(R1*C1) + i/C1
%       dSOC/dt = -i / (3600*Q)
%   scaled to the pack by Ns series cells and Np parallel strings.
%
%   P_req   - requested pack power at the terminals [W], + = discharge,
%             - = charge.
%   P_actual - power actually delivered (0 once the BMS has cut off).
%   V_pack  - pack terminal voltage [V].
%
%   The cell current for a given power comes from solving
%       R0*i^2 - (OCV - v1)*i + P_cell = 0.
%   If there is no real solution the pack cannot deliver that power.
%   The BMS cuts the pack off (latched) when SOC < soc_min, the loaded
%   cell voltage < v_cell_min, the cell current limit is exceeded, or the
%   requested power is not deliverable. bs.cut_reason records which:
%   'energy' (SOC), 'voltage' (loaded cell voltage), 'current', 'power'.

[R0, R1, Q_Ah] = battery_cell_params(b);
ncell = b.Ns * b.Np;

if bs.depleted
    P_actual = 0;
    bs.i_cell = 0;
    a = exp(-dt / (R1 * b.C1));
    bs.v1 = a * bs.v1;
    bs.v_cell = battery_ocv(b, bs.soc) - bs.v1;
    V_pack = b.Ns * bs.v_cell;
    return
end

ocv = battery_ocv(b, bs.soc);
e = ocv - bs.v1;
P_cell = P_req / ncell;
disc = e^2 - 4 * R0 * P_cell;

cut = false;
reason = '';
if disc < 0
    cut = true;                          % power not deliverable
    reason = 'power';
    i = e / (2 * R0);
else
    i = (e - sqrt(disc)) / (2 * R0);
end
if i > b.i_cell_max
    cut = true;
    reason = 'current';
end

v_cell = e - i * R0;
if P_req > 0 && v_cell < b.v_cell_min && ~cut
    cut = true;
    reason = 'voltage';
end
if P_req > 0 && bs.soc <= b.soc_min
    cut = true;
    reason = 'energy';
end

if cut && P_req > 0
    bs.depleted = true;
    bs.cut_reason = reason;
    P_actual = 0;
    i = 0;
    v_cell = ocv - bs.v1;
else
    P_actual = P_req;
end

% exact discretisation of the RC branch for constant current over dt
a = exp(-dt / (R1 * b.C1));
bs.v1 = a * bs.v1 + (1 - a) * R1 * i;
bs.soc = bs.soc - i * dt / (3600 * Q_Ah);
bs.soc = min(max(bs.soc, 0), 1);
bs.i_cell = i;
bs.v_cell = v_cell;
V_pack = b.Ns * v_cell;
end
