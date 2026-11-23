function prepare_terrain(force)
% PREPARE_TERRAIN  One-off data prep: crop Copernicus GLO-30 to the AOI and fetch two satellite
% textures (wide base ~6 m/px, high-resolution Mashaer ~2 m/px) as stitched Esri World Imagery tiles.
if nargin < 1, force = false; end
cfg = config();
if isfile(cfg.demMat) && isfile(cfg.texBase) && isfile(cfg.texMashaer) && ~force, return; end
if ~exist(cfg.demDir, 'dir'), mkdir(cfg.demDir); end
ring = readmatrix(cfg.perimeterCsv);
aoi.lat = [min(ring(:,1)) max(ring(:,1))] + [-1 1] * cfg.aoiMargin;
aoi.lon = [min(ring(:,2)) max(ring(:,2))] + [-1 1] * cfg.aoiMargin;

% --- DEM (Copernicus GLO-30 COG tiles, cropped; downloaded if missing) ---
if ~isfile(cfg.demMat) || force
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
end

% --- Textures ---
meta.base.lat = aoi.lat;  meta.base.lon = aoi.lon;
meta.mashaer.lat = cfg.mashaerLat;  meta.mashaer.lon = cfg.mashaerLon;
if ~isfile(cfg.texBase) || force
    imwrite(esri_mosaic(aoi.lat, aoi.lon, cfg.texBasePx), cfg.texBase, 'Quality', 92);
end
if ~isfile(cfg.texMashaer) || force
    imwrite(esri_mosaic(cfg.mashaerLat, cfg.mashaerLon, cfg.texMashaerPx), cfg.texMashaer, 'Quality', 92);
end
save(cfg.texMeta, 'meta');
fprintf('Textures written (base + Mashaer).\n');
end

function img = esri_mosaic(latL, lonL, nTiles)
% Fetch an nTiles(cols,rows) grid of Esri World Imagery exports (each <= 4096 px), equirectangular.
% Pixel aspect keeps degrees square-ish in lat/lon so the image maps linearly onto the DEM grid.
nc = nTiles(1);  nr = nTiles(2);
dLon = diff(lonL) / nc;  dLat = diff(latL) / nr;
tw = 4096;  th = round(tw * dLat / dLon);
if th > 4096, th = 4096; tw = round(th * dLon / dLat); end
rows = cell(nr, 1);
for r = 1:nr
    cols = cell(1, nc);
    for c = 1:nc
        la1 = latL(2) - r * dLat;  la2 = la1 + dLat;
        lo1 = lonL(1) + (c-1) * dLon;  lo2 = lo1 + dLon;
        url = sprintf(['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?' ...
            'bbox=%.6f,%.6f,%.6f,%.6f&bboxSR=4326&imageSR=4326&size=%d,%d&format=jpg&f=image'], lo1, la1, lo2, la2, tw, th);
        tmp = [tempname '.jpg'];
        for attempt = 1:3
            try, websave(tmp, url, weboptions('Timeout', 120, 'UserAgent', 'capstone-das-figure/0.1')); break;
            catch, pause(3); if attempt == 3, rethrow(lasterror); end %#ok<LERR>
            end
        end
        cols{c} = imread(tmp);  delete(tmp);
    end
    rows{r} = cat(2, cols{:});
    fprintf('  texture row %d/%d\n', r, nr);
end
img = cat(1, rows{:});
fprintf('  mosaic %dx%d px\n', size(img,2), size(img,1));
end
