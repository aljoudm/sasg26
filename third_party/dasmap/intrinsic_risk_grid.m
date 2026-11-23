function G = intrinsic_risk_grid(cfg, lat0, lon0)
% INTRINSIC_RISK_GRID  Intrinsic risk (terrain + roads ONLY, no CCTV visibility term) on the 30 m DEM grid, for zoning.
%   risk = zone_w(1)*slope_norm + zone_w(2)*road_dist_norm, smoothed (same sigma as the figure's risk). The weights are
%   m.zone_w: the figure's weights with the CCTV term dropped and renormalised to sum 1. compute_risk.m is NOT changed.
%   Returns pixel coordinates in a local metric frame (x east, y north [m]; origin lat0/lon0) and the risk grid.
m = cfg.m;
S = load(cfg.demMat);   Z = double(S.Z);   lat = S.lat(:);   lon = S.lon(:)';   % lat descending (north first)
[nr, nc] = size(Z);
ky = 111195;   kx = 111195 * cosd(lat0);                                     % m per degree (same constants as compute_risk.m)
dLat = abs(lat(1) - lat(end)) / (nr - 1);   dLon = abs(lon(end) - lon(1)) / (nc - 1);
dyM = dLat * ky;   dxM = dLon * kx;   pxM = mean([dxM dyM]);
ij = @(la, lo) deal(min(max(round((lat(1) - la) / dLat) + 1, 1), nr), min(max(round((lo - lon(1)) / dLon) + 1, 1), nc));

[gx, gy] = gradient(Z, dxM, dyM);
slopeN = min(atand(hypot(gx, gy)) / m.slope_full_deg, 1);

R = load(fullfile(cfg.dataDir, 'roads_osm.mat'));   roads = R.roads;
bwR = false(nr, nc);
for k = 1:numel(roads)
    la = roads(k).lat;   lo = roads(k).lon;
    s = [0; cumsum(hypot(diff(la) * ky, diff(lo) * kx))];
    if s(end) < 1, continue; end
    [su, iu] = unique(s);   sq = (0:20:s(end))';
    [r, c] = ij(interp1(su, la(iu), sq), interp1(su, lo(iu), sq));
    bwR(sub2ind([nr nc], r, c)) = true;
end
roadN = min(bwdist(bwR) * pxM / m.road_full_m, 1);

risk0 = m.zone_w(1) * slopeN + m.zone_w(2) * roadN;
G.risk = imgaussfilt(risk0, m.zone_smooth_sigma);
[LO, LA] = meshgrid(lon, lat);
G.x = (LO - lon0) * kx;   G.y = (LA - lat0) * ky;
G.lat0 = lat0;  G.lon0 = lon0;  G.kx = kx;  G.ky = ky;  G.pxM = pxM;
end
