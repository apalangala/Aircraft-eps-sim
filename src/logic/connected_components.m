function comp = connected_components(n_nodes, edges, closed)
%CONNECTED_COMPONENTS  Label each node with the id of its electrical island.
%
%   comp = CONNECTED_COMPONENTS(n_nodes, edges, closed) returns a 1 x n_nodes
%   vector. Nodes joined through closed contactors share a label.
comp = 1:n_nodes;
changed = true;
while changed
    changed = false;
    for e = 1:size(edges, 1)
        if closed(e)
            a = edges(e, 1);
            b = edges(e, 2);
            m = min(comp(a), comp(b));
            if comp(a) ~= m || comp(b) ~= m
                comp(comp == comp(a) | comp == comp(b)) = m;
                changed = true;
            end
        end
    end
end
end
