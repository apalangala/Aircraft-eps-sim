function test_mil704_steady_state()
%TEST_MIL704_STEADY_STATE  REQ-PQ-01: every powered 270 V and 28 V bus stays
%   inside the MIL-STD-704F normal steady-state band in all fault runs.
R = short_runs();
for k = 1:numel(R)
    s = R(k).out.summary;
    assert(s.hv_ss_ok, sprintf('%s: 270 V bus outside 250-280 V', R(k).name));
    assert(s.lv_ss_ok, sprintf('%s: 28 V bus outside 22-29 V', R(k).name));
end
lim = mil704_limits();
assert(lim.hv.ss_min == 250 && lim.hv.ss_max == 280 && lim.hv.ripple_max == 6, 'Transcribed 270 V limits changed');
assert(lim.lv.ss_min == 22 && lim.lv.ss_max == 29, 'Transcribed 28 V limits changed');
end
