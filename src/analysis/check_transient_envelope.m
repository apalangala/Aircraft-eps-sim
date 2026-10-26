function res = check_transient_envelope(t, v, t0, lim)
%CHECK_TRANSIENT_ENVELOPE  Compare a voltage transient with a MIL-STD-704 envelope.
%
%   res = CHECK_TRANSIENT_ENVELOPE(t, v, t0, lim) where lim is
%   mil704_limits().hv or .lv and t0 is when the disturbance starts.
%   Envelope corner points are joined by straight lines in time.
%
%   res.pass          true if v stays inside the envelope for t >= t0
%   res.margin_over   smallest (upper limit - v) [V]  (negative = violation)
%   res.margin_under  smallest (v - lower limit) [V]
%   res.v_max, res.v_min, res.t_settle (time after t0 until v stays in the
%   steady-state band, NaN if it never does)

sel = t >= t0;
tt = t(sel) - t0;
vv = v(sel);
up = interp1(lim.env_over_t, lim.env_over_v, tt, 'linear');
lo = interp1(lim.env_under_t, lim.env_under_v, tt, 'linear');
res.margin_over = min(up - vv);
res.margin_under = min(vv - lo);
res.pass = res.margin_over >= 0 && res.margin_under >= 0;
res.v_max = max(vv);
res.v_min = min(vv);
out_band = vv > lim.ss_max | vv < lim.ss_min;
if ~any(out_band)
    res.t_settle = 0;
elseif out_band(end)
    res.t_settle = NaN;
else
    res.t_settle = tt(find(out_band, 1, 'last') + 1);
end
res.env_t = tt;
res.env_up = up;
res.env_lo = lo;
end
