function loss = conv_loss(P_out, P_rated, eta_rated, noload_frac, energised)
%CONV_LOSS  Power loss of a converter at output power P_out [W].
%
%   loss = P0 + k * P_out^2, where the rated-power loss is
%   P_rated * (1/eta_rated - 1) and a fraction noload_frac of it is fixed
%   (switching, magnetising, control power). This gives the usual curve:
%   poor efficiency at light load, peak efficiency mid-range.
%
%   A de-energised converter has zero loss. Works element-wise.

if nargin < 5
    energised = true;
end
loss_rated = P_rated .* (1 ./ eta_rated - 1);
P0 = noload_frac .* loss_rated;
k  = (loss_rated - P0) ./ P_rated.^2;
loss = (P0 + k .* abs(P_out).^2) .* double(energised);
end
