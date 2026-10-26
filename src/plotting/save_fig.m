function save_fig(fig, fname)
%SAVE_FIG  Write a figure to PNG at 150 dpi and close it.
dname = fileparts(fname);
if ~isempty(dname) && ~exist(dname, 'dir')
    mkdir(dname);
end
set(fig, 'PaperPositionMode', 'auto');
print(fig, fname, '-dpng', '-r150');
close(fig);
end
