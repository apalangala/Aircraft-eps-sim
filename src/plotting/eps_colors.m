function c = eps_colors()
%EPS_COLORS  Plot colours used across all figures (hex -> RGB 0..1).
%   Categorical order is fixed so each source/bus keeps its colour in every
%   figure. Palette checked for colour-vision-deficiency separation.
hex = @(s) [hex2dec(s(2:3)) hex2dec(s(4:5)) hex2dec(s(6:7))] / 255;
c.s1 = hex('#2a78d6');   % blue    GEN1 / HV1 / series 1
c.s2 = hex('#eb6834');   % orange  GEN2 / HV2 / series 2
c.s3 = hex('#1baf7a');   % aqua    APU  / HVE / series 3
c.s4 = hex('#eda100');   % yellow  battery / series 4
c.s5 = hex('#e87ba4');   % magenta series 5
c.s7 = hex('#4a3aa7');   % violet  series 7
c.ink = hex('#0b0b0b');
c.ink2 = hex('#52514e');
c.grid = hex('#d9d8d4');
c.limit = hex('#8a8985');
c.good = hex('#1baf7a');
c.warn = hex('#eda100');
c.crit = hex('#e34948');
c.full = hex('#c9dcf3');   % load at full power (calm)
c.reduced = hex('#7fb0e8');
c.phase = [0.96 0.96 0.95; 0.92 0.92 0.91];
end
