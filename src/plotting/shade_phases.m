function shade_phases(m, ylims, label)
%SHADE_PHASES  Alternate grey bands for mission phases (time in minutes).
c = eps_colors();
hold on
for k = 1:numel(m.names)
    x0 = m.t_start(k) / 60;
    x1 = m.t_end(k) / 60;
    patch([x0 x1 x1 x0], [ylims(1) ylims(1) ylims(2) ylims(2)], c.phase(mod(k, 2) + 1, :), ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
    if nargin > 2 && label
        short = struct('TAXI', 'TAXI', 'TAKEOFF', 'T/O', 'CLIMB', 'CLIMB', 'CRUISE', 'CRUISE', ...
            'MISSION', 'MISSION', 'RTB', 'RTB', 'APPROACH', 'APPR');
        nm = m.names{k};
        if isfield(short, nm), nm = short.(nm); end
        text((x0 + x1) / 2, ylims(2), nm, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 7, 'Color', c.ink2);
    end
end
end
