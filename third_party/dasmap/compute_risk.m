function R = compute_risk(cfg, T, F, roads, cctv)
% COMPUTE_RISK  Weak-coverage / easy-infiltration score on the DEM grid, inside a corridor around the fibre:
%   risk = W_SLOPE*slope_norm + W_BLIND*not_visible + W_ROAD*road_dist_norm      (weights: config.m)
%   slope    : from the Copernicus DEM; blind spot: cell not seen by any CCTV (viewshed, DEM + mast height);
%   road dist: distance to the nearest major road (OpenStreetMap). The weights are DESIGN ASSUMPTIONS.
S = load(cfg.demMat);   Z = double(S.Z);   lat = S.lat(:);   lon = S.lon(:)';   % lat descending (north first)
[nr, nc] = size(Z);
dLat = abs(lat(1) - lat(end)) / (nr - 1);   dLon = abs(lon(end) - lon(1)) / (nc - 1);
dyM = dLat * 111195;   dxM = dLon * 111195 * cosd(T.lat0);   pxM = mean([dxM dyM]);
ij = @(la, lo) deal(min(max(round((lat(1) - la) / dLat) + 1, 1), nr), min(max(round((lo - lon(1)) / dLon) + 1, 1), nc));

% slope
[gx, gy] = gradient(Z, dxM, dyM);
slopeN = min(atand(hypot(gx, gy)) / cfg.SLOPE_FULL_DEG, 1);

% corridor around the fibre
[r, c] = ij(F.lat, F.lon);   bw = false(nr, nc);   bw(sub2ind([nr nc], r, c)) = true;
dPer = bwdist(bw) * pxM;

% road distance
bwR = false(nr, nc);
for k = 1:numel(roads)
    la = roads(k).lat;   lo = roads(k).lon;
    s = [0; cumsum(hypot(diff(la) * 111195, diff(lo) * 111195 * cosd(T.lat0)))];
    if s(end) < 1, continue; end
    [su, iu] = unique(s);   sq = (0:20:s(end))';
    [r, c] = ij(interp1(su, la(iu), sq), interp1(su, lo(iu), sq));
    bwR(sub2ind([nr nc], r, c)) = true;
end
roadN = min(bwdist(bwR) * pxM / cfg.ROAD_FULL_M, 1);

% camera visibility: DIRECTIONAL model, identical to the wedges drawn (heading, FOV angle, range)
vis = false(nr, nc);
dgLat = cfg.camRangeKm / 111.195;   dgLon = cfg.camRangeKm / (111.195 * cosd(T.lat0));
for k = 1:numel(cctv)
    la = cctv(k).lat;   lo = cctv(k).lon;
    r1 = max(1, round((lat(1) - (la + dgLat)) / dLat) + 1);    r2 = min(nr, round((lat(1) - (la - dgLat)) / dLat) + 1);
    c1 = max(1, round((lo - dgLon - lon(1)) / dLon) + 1);      c2 = min(nc, round((lo + dgLon - lon(1)) / dLon) + 1);
    Zs = Z(r1:r2, c1:c2);
    Rs = georefpostings([lat(r2) lat(r1)], [lon(c1) lon(c2)], size(Zs), 'ColumnsStartFrom', 'north');
    v = viewshed(Zs, Rs, la, lo, cfg.camMastM, cfg.targetM);
    [LO, LA] = meshgrid(lon(c1:c2), lat(r1:r2));
    dk = hypot((LA - la) * 111.195, (LO - lo) * 111.195 * cosd(T.lat0));
    ang = atan2((LA - la) * 111.195, (LO - lo) * 111.195 * cosd(T.lat0));      % bearing of each cell (x east, y north)
    inFov = abs(angle(exp(1i * (ang - cctv(k).heading)))) <= deg2rad(cfg.camFovDeg / 2) | dk < 0.05;
    vis(r1:r2, c1:c2) = vis(r1:r2, c1:c2) | (logical(v) & dk <= cfg.camRangeKm & inFov);
end

risk0 = cfg.W_SLOPE * slopeN + cfg.W_BLIND * double(~vis) + cfg.W_ROAD * roadN;
risk  = imgaussfilt(risk0, 6);
fade  = min(max((cfg.corridorKm * 1000 - dPer) / 500, 0), 1);               % soft edge over the last 500 m
alpha = 0.72 * min(max((risk - cfg.riskShowFrom) / 0.40, 0), 1) .* fade;

R.risk = risk;   R.alpha = alpha;
R.at      = griddedInterpolant({flip(lat), lon(:)}, flipud(risk),  'linear', 'nearest');
R.alphaAt = griddedInterpolant({flip(lat), lon(:)}, flipud(alpha), 'linear', 'nearest');
inC = dPer < cfg.corridorKm * 1000;
R.blindFrac = 1 - mean(vis(inC));   R.highFrac = mean(risk(inC) > 0.6);
fprintf('Risk            : corridor +/-%.1f km, %.0f%% not covered by CCTV, %.0f%% of cells above 0.6\n', ...
    cfg.corridorKm, 100 * R.blindFrac, 100 * R.highFrac);
end
