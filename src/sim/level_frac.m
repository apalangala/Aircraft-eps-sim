function fr = level_frac(info, lvl)
%LEVEL_FRAC  Power fraction of each load for level indices lvl (1 = full).
fr = info.levmat(sub2ind(size(info.levmat), 1:info.n, lvl));
end
