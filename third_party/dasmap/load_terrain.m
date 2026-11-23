function T = load_terrain(cfg)
% LOAD_TERRAIN  Local km coordinates, DEM interpolant and display meshes (base + Mashaer).
% Display z = elevation [km] * VERT_EXAG, so DataAspectRatio [1 1 1] shows the exaggeration.
S = load(cfg.demMat);   M = load(cfg.texMeta);
T.lat0 = mean(M.meta.base.lat);   T.lon0 = mean(M.meta.base.lon);
T.ky = 111.195;   T.kx = 111.195 * cosd(T.lat0);        % km/deg (R = 6371 km, matches haversine)
T.VE = cfg.VERT_EXAG;
T.toX = @(lon) (lon - T.lon0) * T.kx;
T.toY = @(lat) (lat - T.lat0) * T.ky;
T.toLon = @(x) x / T.kx + T.lon0;
T.toLat = @(y) y / T.ky + T.lat0;

latA = flipud(S.lat(:));  ZA = flipud(double(S.Z));
T.F = griddedInterpolant({latA, S.lon(:)}, ZA, 'linear', 'nearest');
T.heightXY = @(x, y) T.F(T.toLat(y), T.toLon(x)) / 1000 * T.VE;     % display km

T.base    = mesh(T, M.meta.base.lat,    M.meta.base.lon,    0.045);
T.mashaer = mesh(T, M.meta.mashaer.lat, M.meta.mashaer.lon, 0.030);
T.base.tex = cfg.texBase;   T.mashaer.tex = cfg.texMashaer;
end

function m = mesh(T, latL, lonL, stepKm)
% Regular lat/lon grid (lat ASCENDING; draw functions flip rows so image row 1 = north).
nx = round(diff(lonL) * T.kx / stepKm) + 1;   ny = round(diff(latL) * T.ky / stepKm) + 1;
lon = linspace(lonL(1), lonL(2), nx);          lat = linspace(latL(1), latL(2), ny);
[LON, LAT] = meshgrid(lon, lat);
m.X = (LON - T.lon0) * T.kx;   m.Y = (LAT - T.lat0) * T.ky;
m.Z = reshape(T.F(LAT(:), LON(:)), size(LAT)) / 1000 * T.VE;
m.lat = latL;  m.lon = lonL;  m.stepKm = stepKm;
end
