function dx = hvdc_rhs(tp, x, G_load, P_cpl, connected, Vref)
%HVDC_RHS  State derivatives of the averaged 270 V DC channel.
%
%   x = [i_s; v_bus; i_f; v_cf; x_pi; E; v_cd]
%     i_s   generator (source) current           [A]
%     v_bus main-bus voltage                      [V]
%     i_f   radar-PSU filter inductor current     [A]
%     v_cf  radar-PSU filter capacitor voltage    [V]
%     x_pi  regulator integrator state            [V] (trim on top of the set-point)
%     E     generator EMF                         [V]
%     v_cd  damping-branch capacitor voltage      [V]
%
%   G_load    - conductance of the resistive load on the bus [S]
%   P_cpl     - power drawn by the constant-power load [W]
%   connected - false while the source is disconnected (bus transfer)
%   Vref      - regulator set-point [V] (optional, default tp.Vref; a ramp
%               gives a soft start after a transfer)
%
%   Equations
%     L_s di_s/dt  = E - R_s i_s - v_bus
%     C_dc dv/dt   = i_s - G v - i_f
%     L_f di_f/dt  = v - R_f i_f - v_cf
%     C_f dv_cf/dt = i_f - i_cpl - i_d,  i_cpl = P/v_cf, i_d = (v_cf - v_cd)/R_d
%     C_d dv_cd/dt = i_d
%     dx_pi/dt     = Ki (Vref - v)
%     tau dE/dt    = Vref + Kp (Vref - v) + x_pi - E   (E clamped to [E_min, E_max])
%   The set-point is fed forward, so the integrator only trims out the
%   source resistance drop and a set-point ramp is followed without lag.

if nargin < 6
    Vref = tp.Vref;
end
i_s = x(1); v = x(2); i_f = x(3); v_cf = x(4); x_pi = x(5); E = x(6); v_cd = x(7);

if v_cf > tp.V_uvlo
    i_cpl = P_cpl / v_cf;
else
    i_cpl = P_cpl / tp.V_uvlo^2 * v_cf;      % resistive below UVLO
end

if tp.damp
    i_d = (v_cf - v_cd) / tp.R_d;
    dv_cd = i_d / tp.C_d;
else
    i_d = 0;
    dv_cd = 0;
end

err = Vref - v;
if connected
    di_s = (E - tp.R_s * i_s - v) / tp.L_s;
else
    di_s = 0;                         % contactor open (simulator holds i_s = 0)
end
dv    = (i_s - G_load * v - i_f) / tp.C_dc;
di_f  = (v - tp.R_f * i_f - v_cf) / tp.L_f;
dv_cf = (i_f - i_cpl - i_d) / tp.C_f;

dx_pi = tp.Ki * err;
E_cmd = Vref + tp.Kp * err + x_pi;
dE = (E_cmd - E) / tp.tau_ex;
% anti-windup: stop integrating while the EMF is pinned at a limit
if (E >= tp.E_max && err > 0) || (E <= tp.E_min && err < 0)
    dx_pi = 0;
end
if (E >= tp.E_max && dE > 0) || (E <= tp.E_min && dE < 0)
    dE = 0;
end

dx = [di_s; dv; di_f; dv_cf; dx_pi; dE; dv_cd];
end
