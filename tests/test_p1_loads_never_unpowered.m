function test_p1_loads_never_unpowered()
%TEST_P1_LOADS_NEVER_UNPOWERED  REQ-LM-01: flight-critical loads keep power
%   through every single and dual failure that leaves a source available,
%   including battery-only operation to touchdown.
R = short_runs();
for k = 1:numel(R)
    s = R(k).out.summary;
    assert(s.p1_unpowered_s == 0, sprintf('%s: P1 loads unpowered for %.1f s', R(k).name, s.p1_unpowered_s));
    assert(~s.any_deficit, sprintf('%s: flight-critical demand exceeded a source', R(k).name));
    % P1 loads are never shed (status 0 or 1 with bus alive)
    lg = R(k).out.log;
    p1 = [R(k).out.L.prio] == 1;
    st = lg.status(p1, :);
    assert(all(st(:) == 2 | st(:) == -1), sprintf('%s: a P1 load was shed', R(k).name));
end
end
