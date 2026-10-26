function y = interp_lin(xt, yt, x)
%INTERP_LIN  Fast scalar linear interpolation with end clamping.
%   Same result as interp1(xt, yt, x, 'linear') for scalar x inside the
%   table, clamped outside it. Written out because interp1 is slow when
%   called once per time step in Octave.
if x <= xt(1)
    y = yt(1);
    return
end
if x >= xt(end)
    y = yt(end);
    return
end
k = find(xt > x, 1, 'first') - 1;
y = yt(k) + (yt(k+1) - yt(k)) * (x - xt(k)) / (xt(k+1) - xt(k));
end
