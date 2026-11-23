function cfg = prepare_terrain_sudair(force)
% PREPARE_TERRAIN_SUDAIR  Stage B. Adapted from DAS-map prepare_terrain.m (same method; site inputs changed):
% Copernicus GLO-30 tile(s) cropped to plant bbox + margin, Esri World Imagery textures (wide base + plant detail).
% Returns a cfg struct with the fields load_terrain / draw_terrain expect.
if nargin < 1, force = false; end
c = sasg_config();
cfg.demDir = fullfile(c.dataDir, 'dem');  cfg.demMat = fullfile(cfg.demDir, 'dem_aoi.mat');
cfg.texBase = fullfile(cfg.demDir, 'tex_base.jpg');  cfg.texMashaer = fullfile(cfg.demDir, 'tex_plant.jpg');   % "mashaer" slot = plant detail
cfg.texMeta = fullfile(cfg.demDir, 'tex_meta.mat');  cfg.VERT_EXAG = 2;   % [ASSUMED: DAS-map value]
cfg.aoiMargin = 0.05;  cfg.detailMargin = 0.012;                       % deg [ASSUMED: context around plant]
cfg.imageryCredit = 'Imagery: Esri, Vantor, Earthstar Geographics, and the GIS User Community. Terrain: Copernicus DEM GLO-30. Data: OpenStreetMap contributors.';
if isfile(cfg.demMat) && isfile(cfg.texBase) && isfile(cfg.texMashaer) && isfile(cfg.texMeta) && ~force, return; end
if ~exist(cfg.demDir, 'dir'), mkdir(cfg.demDir); end
ring = readmatrix(c.boundaryCsv);
aoi.lat = [min(ring(:,1)) max(ring(:,1))] + [-1 1] * cfg.aoiMargin;
aoi.lon = [min(ring(:,2)) max(ring(:,2))] + [-1 1] * cfg.aoiMargin;
det.lat = [min(ring(:,1)) max(ring(:,1))] + [-1 1] * cfg.detailMargin;
det.lon = [min(ring(:,2)) max(ring(:,2))] + [-1 1] * cfg.detailMargin;
%% DEM
base = 'https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_N%02d_00_E%03d_00_DEM/Copernicus_DSM_COG_10_N%02d_00_E%03d_00_DEM.tif';
latT = floor(aoi.lat(1)):floor(aoi.lat(2));  lonT = floor(aoi.lon(1)):floor(aoi.lon(2));
assert(isscalar(latT), 'AOI spans several latitude tiles - extend the mosaic code.');
Z = [];  lon = [];
for t = lonT
    f = fullfile(cfg.demDir, sprintf('Copernicus_DSM_COG_10_N%02d_00_E%03d_00_DEM.tif', latT, t));
    if ~isfile(f), websave(f, sprintf(base, latT, t, latT, t)); end
    [A, R] = readgeoraster(f, 'OutputType', 'double');
    lat = linspace(R.LatitudeLimits(2), R.LatitudeLimits(1), size(A,1))';
    lon = [lon, linspace(R.LongitudeLimits(1), R.LongitudeLimits(2), size(A,2))]; %#ok<AGROW>
    Z = [Z, A]; %#ok<AGROW>
end
ri = lat >= aoi.lat(1) & lat <= aoi.lat(2);  ci = lon >= aoi.lon(1) & lon <= aoi.lon(2);
lat = lat(ri);  lon = lon(ci);  Z = single(Z(ri, ci)); %#ok<NASGU>
save(cfg.demMat, 'Z', 'lat', 'lon');
fprintf('DEM: %dx%d, %.0f..%.0f m\n', size(Z,1), size(Z,2), min(Z(:)), max(Z(:)));
% the 1-degree source tile is 25 MB: crop is kept, tile removed to keep the OneDrive folder small
try, delete(fullfile(cfg.demDir, '*.tif')); catch, end
%% textures
meta.base = aoi;  meta.mashaer = det;
imwrite(esri_one(aoi.lat, aoi.lon), cfg.texBase, 'Quality', 88);
imwrite(esri_one(det.lat, det.lon), cfg.texMashaer, 'Quality', 90);
save(cfg.texMeta, 'meta');
fprintf('Textures written (base + plant detail).\n');
end

function img = esri_one(latL, lonL)
% One Esri World Imagery export (<= 4096 px), equirectangular, pixel aspect = degree aspect.
dLon = diff(lonL);  dLat = diff(latL);  tw = 4096;  th = round(tw * dLat / dLon);
if th > 4096, th = 4096; tw = round(th * dLon / dLat); end
url = sprintf(['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?' ...
    'bbox=%.6f,%.6f,%.6f,%.6f&bboxSR=4326&imageSR=4326&size=%d,%d&format=jpg&f=image'], lonL(1), latL(1), lonL(2), latL(2), tw, th);
tmp = [tempname '.jpg'];
for a = 1:3
    try, websave(tmp, url, weboptions('Timeout', 120, 'UserAgent', 'sasg26-poster/0.1')); break;
    catch err, pause(3); if a == 3, rethrow(err); end
    end
end
img = imread(tmp);  delete(tmp);  fprintf('  imagery %dx%d px\n', size(img,2), size(img,1));
end
