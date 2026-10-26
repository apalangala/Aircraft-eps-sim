function test_apu_sequencing()
%TEST_APU_SEQUENCING  REQ-BM-06: the APU is started when a generator is lost
%   and picks up the dead side only after its start time.
p = eps_params();
R = short_runs();
out = R(strcmp({R.name}, 'gen1_fail_apu_ok')).out;
assert(abs(out.apu_start_cmd_t - 1900) <= p.dt + 1e-9, 'APU start not commanded at the generator loss');
delay = out.apu_online_t - out.apu_start_cmd_t;
assert(delay >= p.apu.start_time - 1e-9 && delay <= p.apu.start_time + p.dt + 1e-9, ...
    sprintf('APU came online after %.2f s, expected %.0f s', delay, p.apu.start_time));
lg = out.log;
before = lg.t < out.apu_online_t;
assert(all(lg.P_src(3, before) == 0), 'APU delivered power before it was online');
after = lg.t > out.apu_online_t + 1;
assert(all(lg.P_src(3, after) > 0), 'APU not carrying load after coming online');
assert(all(lg.P_src(1, lg.t > 1900 + p.dt) == 0), 'Failed GEN1 still delivering power');

% APU start failure: never comes online, the remaining generator carries both sides
out = R(strcmp({R.name}, 'gen2_fail_apu_fails')).out;
assert(isnan(out.apu_online_t), 'APU came online although its start failed');
assert(all(out.log.P_src(3, :) == 0), 'Failed APU delivered power');
end
