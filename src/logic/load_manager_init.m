function lm = load_manager_init(L)
%LOAD_MANAGER_INIT  Initial state of the load manager.
n = numel(L);
lm.lvl = ones(1, n);            % index into L(k).levels, 1 = full power
lm.over_timer = struct('GEN1', 0, 'GEN2', 0, 'APU', 0, 'BATT', 0, 'DCDC', 0, 'INV', 0);
lm.restore_timer = 0;
lm.restore_cand = 0;
lm.prev_live = true(1, n);
lm.n_shed_events = zeros(1, n);
lm.n_restore_events = zeros(1, n);
end
