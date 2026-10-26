function test_radar_headroom()
%TEST_RADAR_HEADROOM  Sanity of the headroom study: thresholds ordered the
%   way the architecture says they must be, and loading grows with radar power.
r = study_radar_headroom([], [], [], '');
thr = r.threshold_kW;     % [A normal, B gen lost + APU, C gen lost no APU]
assert(thr(1) > thr(2) && thr(2) > thr(3), 'Headroom thresholds not ordered A > B > C');
d = diff(r.loading, 1, 2);
assert(all(d(:) >= -1e-12), 'Source loading should not fall as radar power rises');
assert(r.loading(1, 1) < 1, 'Normal configuration overloaded with the radar off');
end
