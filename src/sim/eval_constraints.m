function C = eval_constraints(p, pf, caps)
%EVAL_CONSTRAINTS  Capacity constraints that load shedding must respect.
%
%   C is a struct array, one entry per active constraint:
%     name      'GEN1' | 'GEN2' | 'APU' | 'BATT' | 'DCDC' | 'INV'
%     usage     present loading [W]
%     cap_cont  continuous capacity [W]
%     cap_ovl   capacity available right now incl. short-time overload [W]
%     member    1xN logical, loads that load this constraint
%     gain      1xN, change in usage per watt of load change

n = numel(pf.P_served);
C = struct('name', {}, 'usage', {}, 'cap_cont', {}, 'cap_ovl', {}, ...
           'member', {}, 'gain', {});

for s = 1:4
    member = pf.load_src_idx == s;
    if ~(pf.P_src(s) > 0 || any(member))
        continue
    end
    nm = pf.src_names{s};
    C(end+1) = cons(nm, pf.P_src(s), caps.(nm).cont, caps.(nm).ovl, member, pf.gain); %#ok<AGROW>
end

if pf.live.LV
    cap = pf.n_dcdc * p.dcdc(1).P_rated;
    C(end+1) = cons('DCDC', pf.LV_out, cap, 1.1 * cap, pf.isLV, ones(1, n));
end

if pf.live.AC
    C(end+1) = cons('INV', pf.AC_out, p.inv.P_rated, 1.1 * p.inv.P_rated, pf.isAC, ones(1, n));
end
end

function c = cons(name, usage, cap_cont, cap_ovl, member, gain)
c.name = name;
c.usage = usage;
c.cap_cont = cap_cont;
c.cap_ovl = cap_ovl;
c.member = member;
c.gain = gain;
end
