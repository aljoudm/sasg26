function cfg = viz_cfg(themeName)
% VIZ_CFG  Display configuration for the Sudair figures: the DAS-map palette, fonts and sizes (config.m, third_party/dasmap), light theme.
% Camera = DAS-map main view (az 180, el 30, fov 30, perspective) with dist scaled to the plant [DERIVED: same framing as DAS-map main view].
if nargin < 1, themeName = 'light'; end
c.bg = [0.04 0.07 0.10];  c.text = [0.85 0.93 0.97];  c.cyan = [0 0.9 1];  c.green = [0.2 1 0.45];  c.yellow = [1 0.85 0.1];  c.red = [1 0.15 0.15];
c.iu = [1 1 1];  c.cctv = [0.5 0.68 1];  c.fibreCmap = interp1([0 1/3 2/3 1], [c.cyan; c.green; c.yellow; c.red], linspace(0, 1, 256));
cfg.col = c;
fams = {'Segoe UI', 'Helvetica Neue', 'Arial'};  cfg.font.name = fams{find(ismember(fams, listfonts), 1)};
cfg.font.site = struct('size', 9.5, 'weight', 'bold');   cfg.font.asset = struct('size', 7.5, 'weight', 'bold');
cfg.font.panel = struct('size', 7.0, 'weight', 'normal');  cfg.font.title = struct('size', 6.8, 'weight', 'bold');  cfg.font.note = struct('size', 5.6, 'weight', 'normal');
cfg.figSizeIn = [8.7 5.2];  cfg.uiScale = 1;  cfg.exportDpi = 300;  cfg.gfx = 0.55;
cfg.theme = get_theme(cfg, themeName);
cfg.imageryCredit = 'Imagery: Esri, Vantor, Earthstar Geographics, and the GIS User Community. Terrain: Copernicus DEM GLO-30. Data: OpenStreetMap contributors.';
% zone colours (same as results_zones/zone_cells_map.png): Cold, Neutral, Hot
cfg.zoneCol = [0.20 0.45 0.80; 0.98 0.80 0.15; 0.85 0.12 0.12];
% camera: DAS-map cfg.camera = az 180, el 30, dist 53, fov 30
c0 = sasg_config();
mkCsv = 'C:\Users\aljou\Downloads\DAS Map\data\boundary_perimeter.csv';          % Makkah fibre path (read-only source)
sd = readmatrix(c0.boundaryCsv);
diagKm = @(r) hypot(range(r(:,2)) * 111.195 * cosd(mean(r(:,1))), range(r(:,1)) * 111.195);
if isfile(mkCsv), cfg.diag_makkah_km = diagKm(readmatrix(mkCsv));
else, cfg.diag_makkah_km = 46.658;   % [DERIVED] same formula on aljoudm/DAS-map- a25fd0c data/boundary_perimeter.csv (other computers)
end  cfg.diag_sudair_km = diagKm(sd);
cfg.camDistScale = 0.88;                                                                    % only knob for framing adjustments
cfg.camera = struct('az', 180, 'el', 30, 'fov', 30, 'dist', 53 * cfg.diag_sudair_km / cfg.diag_makkah_km * cfg.camDistScale);
end
