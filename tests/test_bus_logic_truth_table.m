function test_bus_logic_truth_table()
%TEST_BUS_LOGIC_TRUTH_TABLE  REQ-BM-01..05: every combination of source health.
topo = eps_topology();
for code = 0:15
    h.gen_ok = [bitget(code, 1) bitget(code, 2)] == 1;
    h.apu_ok = bitget(code, 3) == 1;
    h.batt_ok = bitget(code, 4) == 1;
    bm = bus_manager(h);
    comp = connected_components(numel(topo.nodes), topo.edges, bm.closed);
    active = [h.gen_ok(1) && bm.closed(1), h.gen_ok(2) && bm.closed(2), h.apu_ok && bm.closed(3), bm.closed(8)];
    tag = sprintf('gen1=%d gen2=%d apu=%d batt=%d', h.gen_ok(1), h.gen_ok(2), h.apu_ok, h.batt_ok);

    % REQ-BM-01: never more than one source in an island (no paralleling)
    for cid = unique(comp)
        assert(sum(active & comp(1:4) == cid) <= 1, ['Sources paralleled: ' tag]);
    end
    % REQ-BM-02: a failed source is never connected
    assert(~(bm.closed(1) && ~h.gen_ok(1)), ['Failed GEN1 connected: ' tag]);
    assert(~(bm.closed(2) && ~h.gen_ok(2)), ['Failed GEN2 connected: ' tag]);
    assert(~(bm.closed(3) && ~h.apu_ok), ['Failed APU connected: ' tag]);
    assert(~(bm.closed(8) && ~h.batt_ok), ['Failed battery connected: ' tag]);
    % REQ-BM-03: at most one essential feed closed
    assert(~(bm.closed(6) && bm.closed(7)), ['Both essential feeds closed: ' tag]);
    % REQ-BM-04: if any source is healthy, the essential bus is powered
    any_src = any(h.gen_ok) || h.apu_ok || h.batt_ok;
    assert(any_src == ~strcmp(bm.feed_HVE, 'NONE'), ['HVE powered state wrong: ' tag]);
    % REQ-BM-05: if any main source is healthy, both main buses are powered
    if any(h.gen_ok) || h.apu_ok
        assert(~strcmp(bm.feed_HV1, 'NONE') && ~strcmp(bm.feed_HV2, 'NONE'), ['Main bus left dead: ' tag]);
        assert(~bm.closed(8), ['Battery discharging while a main source is available: ' tag]);
    end
    % the feed reported for each bus must be the source actually connected
    % to it through closed contactors (this caught a bus-tie logic bug)
    bus_node = [5 7 8];
    feeds = {bm.feed_HV1, bm.feed_HV2, bm.feed_HVE};
    for b = 1:3
        if strcmp(feeds{b}, 'NONE')
            assert(~any(active & comp(1:4) == comp(bus_node(b))), ['Bus has a source but reports NONE: ' tag]);
        else
            src_node = find(strcmp(topo.nodes, feeds{b}));
            assert(comp(src_node) == comp(bus_node(b)), ['Bus not connected to its reported source: ' tag]);
        end
    end
    % each generator feeds its own side when healthy
    if h.gen_ok(1), assert(strcmp(bm.feed_HV1, 'GEN1'), tag); end
    if h.gen_ok(2), assert(strcmp(bm.feed_HV2, 'GEN2'), tag); end
end
end
