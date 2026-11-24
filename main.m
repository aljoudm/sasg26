% MAIN  SASG 26 poster: Sudair PV (1.5 GW) DAS perimeter pipeline. Runs stages A-F (G, the MILP, is not implemented).
% See RUN.md. Needs MATLAB R2026a (Statistics, Image Processing, Mapping toolboxes) and internet for the first run (OSM, Copernicus, Esri).
addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));  sasg_config();
addpath(fullfile(fileparts(mfilename('fullpath')), 'third_party', 'das_engine'));  addpath(fullfile(fileparts(mfilename('fullpath')), 'tests'));
fetch_boundary_sudair();            % A  boundary, substations, roads        -> data/
prepare_terrain_sudair();           % B  DEM + imagery                       -> data/dem/
run_zones();                        % C  zones                               -> results_zones/
place_fibre_sudair();               % D  interrogator placement                  -> results/placement.*
run_das_sudair(true);               % F  engine on the longest channel       -> results/das_sudair.mat (also needs scenario_sudair)
das_figures();                      % F  figures                             -> poster_figs/das_*
render_twin_sudair(300);            % E  3D twin                             -> poster_figs/twin3d.*
render_intruder_map(300);           % E2 intruder map                        -> poster_figs/intruder_map.*
test_stageA; test_stageC; test_stageD; test_stageF; test_stageE; test_stageE2;
