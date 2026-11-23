function cfg = config(theme)
% CONFIG  All tunable parameters for the digital-twin figure. Edit here only.
%   config()        -> default theme below
%   config('light') -> override the theme (the ONLY difference between the two figure versions)

root = fileparts(mfilename('fullpath'));
cfg.root     = root;
cfg.dataDir  = fullfile(root, 'data');
cfg.outDir   = fullfile(root, 'results_febus');   % FEBUS A1-NEO outputs; the previous (EOSS-device) figures stay in out/
cfg.seed     = 20261101;                 % deterministic output

cfg.THEME = 'dark';                      % 'dark' (presentations) | 'light' (printed report)
cfg.renderThemes = ["light" "dark"];     % both versions are rendered from the SAME scene
if nargin > 0, cfg.THEME = theme; end

% --- Boundary (Haram, OSM relation 19590020; see data/SOURCES.md) ---------
cfg.osmRelationId = 19590020;
cfg.boundaryCsv   = fullfile(cfg.dataDir, 'boundary_haram_osm.csv');
cfg.placeholderCsv = fullfile(cfg.dataDir, 'boundary_PLACEHOLDER.csv');
% Perimeter = Haram + Arafat (Holy Sites admin polygon, OSM rel 19262645) - PROVISIONAL, see SOURCES.md
cfg.mashaerRelationId = 19262645;
cfg.perimeterCsv  = fullfile(cfg.dataDir, 'boundary_perimeter.csv');
cfg.holySitesCsv  = fullfile(cfg.dataDir, 'holy_sites.csv');

% --- Device / fibre / risk / scenario values: ALL come from map_params.m (edit the overrides block there) ----
% Device now FEBUS A1-NEO (datasheet rev. 20260618); tags and sources are in map_params.m.
P = map_params();   cfg.m = P;
cfg.R_CH_KM        = P.R_DAS / 1e3;     % range per channel [km]
cfg.N_CH           = P.N_ch_DAS;        % channels per interrogator unit
cfg.N_CH_ACTIVE    = P.N_ch_active;     % channels that carry a sensing segment (2: one per direction)
cfg.SPATIAL_RES_M  = P.dz_res;          % spatial resolution [m]
cfg.CH_SPACING_M   = P.dz_samp;         % channel spacing [m]
cfg.DENSIFY_STEP_M = P.densify_step;    % polyline densification step [m]
cfg.SLACK_FACTOR   = P.slack_factor;    % cable length / geometric length
cfg.W_SLOPE = P.risk_w(1);  cfg.W_BLIND = P.risk_w(2);  cfg.W_ROAD = P.risk_w(3);
cfg.SLOPE_FULL_DEG = P.slope_full_deg;  cfg.ROAD_FULL_M = P.road_full_m;  cfg.corridorKm = P.corridor_km;
cfg.camRangeKm = P.cam_range_km;  cfg.camFovDeg = P.cam_fov_deg;  cfg.camMastM = P.cam_mast_m;
cfg.targetM = P.target_m;  cfg.riskShowFrom = P.risk_show_from;
cfg.nCCTV = P.n_CCTV;   cfg.nPatrol = P.n_patrol;   cfg.nUAV = P.n_UAV;
cfg.entryMergeKm = P.entry_merge_km;  cfg.cctvRoadKm = P.cctv_road_km;  cfg.patrolBandKm = P.patrol_band_km;
cfg.entryClasses = ["motorway" "trunk" "primary" "motorway_link" "trunk_link" "primary_link"];
cfg.hajjPilgrims2026 = P.hajj_pilgrims_2026;

% --- Mashaer view (inset) ---------------------------------------------------
cfg.mashaerLat = [21.27 21.48];       % extent of the high-resolution Mashaer texture / mesh
cfg.mashaerLon = [39.82 40.04];
cfg.insetEl    = 33;                  % elevation of the (orthographic) inset view [deg]
cfg.insetLabelScale = 0.4;            % label leader height in the inset relative to the main view
cfg.insetAspect = 1.9;                % preferred width / height of the inset
cfg.insetSites = ["Jamarat" "Mina" "Muzdalifah" "Arafat"];   % must lie inside the inset rectangle
cfg.insetMargin_km = 1.8;             % minimum margin between these sites and the rectangle
cfg.insetMarginTop_km = 4.2;          % top margin (screen km) so the site labels above the northern site stay inside
cfg.insetSearchLat = [21.275 21.48];  % where the rectangle edges may be placed
cfg.insetSearchLon = [39.825 40.035];
cfg.simFile = fullfile(cfg.dataDir, 'das_sim', 'das_sim_febus.mat');   % phi-OTDR output (see SOURCES.md)

% --- 3D terrain / imagery (prepare_terrain.m) -------------------------------
cfg.aoiMargin   = 0.05;     % deg of context around the perimeter bounding box
cfg.demDir      = fullfile(cfg.dataDir, 'dem');
cfg.demMat      = fullfile(cfg.demDir, 'dem_aoi.mat');
cfg.texBase     = fullfile(cfg.demDir, 'tex_base.jpg');      % ~6 m/px
cfg.texMashaer  = fullfile(cfg.demDir, 'tex_mashaer.jpg');   % ~2 m/px
cfg.texMeta     = fullfile(cfg.demDir, 'tex_meta.mat');
cfg.texBasePx   = [2 2];
cfg.texMashaerPx= [3 2];
cfg.VERT_EXAG   = 2;        % vertical exaggeration (display only)
cfg.imageryCredit = 'Imagery: Esri, Vantor, Earthstar Geographics, and the GIS User Community. Terrain: Copernicus DEM GLO-30. Data: OpenStreetMap contributors.';

% --- Digital-twin palette (map content; defined once) -----------------------
c.bg      = [0.04 0.07 0.10];
c.text    = [0.85 0.93 0.97];
c.cyan    = [0.00 0.90 1.00];
c.green   = [0.20 1.00 0.45];
c.yellow  = [1.00 0.85 0.10];
c.red     = [1.00 0.15 0.15];
c.iu      = [1.00 1.00 1.00];
c.c2      = [1.00 0.80 0.20];
c.uav     = [0.95 0.98 1.00];
c.cctv    = [0.50 0.68 1.00];
c.patrol  = [0.55 1.00 0.45];
c.entry   = [1.00 1.00 1.00];
c.riskLo  = [1.00 0.75 0.15];     % weak-coverage ramp: amber -> magenta (red is reserved for alarms)
c.riskHi  = [0.85 0.10 0.60];
c.fibreCmap = interp1([0 1/3 2/3 1], [c.cyan; c.green; c.yellow; c.red], linspace(0,1,256));
cfg.col = c;

% --- 3D scene display parameters (NOT to scale where noted) -----------------
cfg.fibreLift        = 0.035;   % display units (km, after VERT_EXAG) above the dilated mesh
cfg.fibreDilateCells = 3;       % ridge-clearance radius in mesh cells (~45 m each)
cfg.uavAlt           = 2.8;     % display altitude above ground [km, NOT to scale]
cfg.uavConeR         = 2.2;     % sensing-cone footprint radius [km, illustrative]
cfg.pulseLenKm       = 4.5;     % light-pulse length along the fibre
cfg.pulseSpacingKm   = 15;      % distance between successive pulses from an IU
cfg.pulsePhase       = 0.45;    % 0..1 position within the pulse cycle (the frame shown)
cfg.camera        = struct('az', 180, 'el', 30, 'dist', 53, 'fov', 30);   % main view (az 180: from due south; the inset uses the same azimuth)
cfg.gfx = 0.55;                 % line-width / marker scale (design was drawn for a 17-inch canvas)

% --- Figure layout: physical size so that fonts stay legible when scaled to page width ----
cfg.figSizeIn  = [8.0 5.0];
cfg.uiScale    = 1;      % scale of fonts / markers / line widths relative to the 8-inch static design (interactive window: > 1)
cfg.exportDpi  = 300;
cfg.layout.main    = [0.000 0.405 1.000 0.595];        % wide oblique map across the top
cfg.layout.rowY    = 0.095;   cfg.layout.rowH = 0.295;     % row of panels below the map
cfg.layout.statusX = [0.006 0.268];                        % status panel: x, width
cfg.layout.insetX  = 0.652;   cfg.layout.insetW = 0.340;   % inset: x, width (height follows from the rectangle)
cfg.layout.traceX  = [0.284 0.358];                        % trace panel: x, width
cfg.layout.legend  = [0.006 0.004 0.775 0.082];
cfg.layout.credit  = [0.790 0.004 0.204 0.084];

% --- Typography (one family; hierarchy by size/weight) ----------------------
fams = {'Segoe UI', 'Helvetica Neue', 'Arial'};
cfg.font.name  = fams{find(ismember(fams, listfonts), 1)};
cfg.font.site  = struct('size', 9.5, 'weight', 'bold');      % holy-site names
cfg.font.asset = struct('size', 7.5, 'weight', 'bold');      % IU-1, C2, event labels
cfg.font.panel = struct('size', 7.0, 'weight', 'normal');    % panel text, legend
cfg.font.title = struct('size', 6.8, 'weight', 'bold');      % panel titles
cfg.font.note  = struct('size', 5.6, 'weight', 'normal');    % attribution, footnotes

cfg.theme = get_theme(cfg, cfg.THEME);
end
