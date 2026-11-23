function c = sasg_config()
% SASG_CONFIG  Paths and site constants for the Sudair port. Values and tags: config/parameters_sasg26.tsv.
root = fileparts(fileparts(mfilename('fullpath')));
c.root = root;  c.dataDir = fullfile(root, 'data');  c.resDir = fullfile(root, 'results');
c.zonesDir = fullfile(root, 'results_zones');  c.figDir = fullfile(root, 'poster_figs');
c.osmWayId = 1317477364;                         % OSM way "Sudair PV IPP" (power=plant, plant:source=solar), found by fetch_boundary_sudair
c.bbox = [25.30 45.30 25.90 45.90];              % [S W N E] search box
c.area_pub_km2 = 30.2;  c.area_tol = 0.10;       % [SOURCE: nsenergy_sudair]
c.boundaryCsv = fullfile(c.dataDir, 'boundary_perimeter.csv');
c.substationCsv = fullfile(c.dataDir, 'substation.csv');
c.UA = 'sasg26-poster/0.1';
c.seed = 20261123;
addpath(genpath(fullfile(root, 'src')));  addpath(fullfile(root, 'third_party', 'dasmap'));
end
