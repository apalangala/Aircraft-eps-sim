function info = load_info(L)
%LOAD_INFO  Pre-computed load-table lookups used every time step.
n = numel(L);
info.n = n;
info.bus = {L.bus};
info.isHV1 = strcmp(info.bus, 'HV1');
info.isHV2 = strcmp(info.bus, 'HV2');
info.isHVE = strcmp(info.bus, 'HVE');
info.isLV  = strcmp(info.bus, 'LV');
info.isAC  = strcmp(info.bus, 'AC');
info.prio = [L.prio];
info.rank = [L.rank];
info.nlev = zeros(1, n);
maxlev = max(arrayfun(@(x) numel(x.levels), L));
info.levmat = zeros(n, maxlev);
for k = 1:n
    info.nlev(k) = numel(L(k).levels);
    info.levmat(k, 1:info.nlev(k)) = L(k).levels;
end
info.D = reshape([L.demand], [], n)';      % n x phases [W]
end
