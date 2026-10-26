function test_no_paralleling_in_sim()
%TEST_NO_PARALLELING_IN_SIM  REQ-BM-01 checked every time step of the fault runs.
R = short_runs();
for k = 1:numel(R)
    s = R(k).out.summary;
    assert(s.max_sources_per_island <= 1, sprintf('%s: two sources in one island', R(k).name));
    assert(~s.gens_ever_paralleled, sprintf('%s: generators paralleled', R(k).name));
end
end
