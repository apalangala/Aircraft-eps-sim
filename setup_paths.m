function root = setup_paths()
%SETUP_PATHS  Add the project folders to the MATLAB/Octave path.
root = fileparts(mfilename('fullpath'));
dirs = {'config', 'scenarios', 'studies', 'tests', ...
        fullfile('src', 'models'), fullfile('src', 'logic'), fullfile('src', 'sim'), ...
        fullfile('src', 'transient'), fullfile('src', 'analysis'), ...
        fullfile('src', 'plotting'), fullfile('src', 'util')};
for k = 1:numel(dirs)
    addpath(fullfile(root, dirs{k}));
end
end
