function results = run_all_tests()
%RUN_ALL_TESTS  Run the test suite (works in MATLAB and GNU Octave).
%
%   results = RUN_ALL_TESTS() runs every test, prints PASS/FAIL with the
%   time taken and the failure message, writes results/test_report.txt and
%   returns a struct array. It errors at the end if any test failed, so it
%   can gate a CI job. docs/requirements.md maps requirements to tests.

root = setup_paths();
tests = {
    'test_bus_logic_truth_table'
    'test_battery_model'
    'test_no_paralleling_in_sim'
    'test_p1_loads_never_unpowered'
    'test_energy_balance'
    'test_shedding_order_and_hysteresis'
    'test_apu_sequencing'
    'test_mil704_steady_state'
    'test_battery_endurance_requirement'
    'test_transient_envelope'
    'test_stability'
    'test_radar_headroom'
    'test_reliability'
};

results = struct('name', tests, 'passed', false, 'seconds', 0, 'message', '');
fprintf('\nRunning %d tests\n', numel(tests));
for k = 1:numel(tests)
    t0 = tic;
    try
        feval(tests{k});
        results(k).passed = true;
        results(k).message = '';
    catch err
        results(k).passed = false;
        results(k).message = err.message;
    end
    results(k).seconds = toc(t0);
    if results(k).passed, tag = 'PASS'; else, tag = 'FAIL'; end
    fprintf('  [%s] %-40s %6.1f s  %s\n', tag, tests{k}, results(k).seconds, results(k).message);
end
n_pass = sum([results.passed]);
fprintf('%d of %d tests passed\n\n', n_pass, numel(tests));

outdir = fullfile(root, 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end
fid = fopen(fullfile(outdir, 'test_report.txt'), 'w');
fprintf(fid, 'Test report\n===========\n\n');
for k = 1:numel(results)
    if results(k).passed, tag = 'PASS'; else, tag = 'FAIL'; end
    fprintf(fid, '[%s] %-40s %6.1f s  %s\n', tag, results(k).name, results(k).seconds, results(k).message);
end
fprintf(fid, '\n%d of %d tests passed\n', n_pass, numel(tests));
fclose(fid);

if n_pass < numel(tests)
    error('run_all_tests:failed', '%d test(s) failed', numel(tests) - n_pass);
end
end
