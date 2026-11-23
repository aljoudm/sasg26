function fibre = compute_fibre(cfg)
% COMPUTE_FIBRE  Densify the boundary, compute length L, N_IU and IU placement.
if isfile(cfg.perimeterCsv)
    ring = readmatrix(cfg.perimeterCsv);  fibre.source = 'OSM Haram + Holy Sites union';
elseif isfile(cfg.boundaryCsv)
    ring = readmatrix(cfg.boundaryCsv);  fibre.source = 'OSM Haram only';
else
    warning('BOUNDARY:PLACEHOLDER', 'Using PLACEHOLDER boundary - not real data.');
    ring = readmatrix(cfg.placeholderCsv);  fibre.source = 'PLACEHOLDER';
end
if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end

R = 6371008.8;                                   % mean Earth radius [m]
seg = hav(ring(1:end-1,:), ring(2:end,:), R);    % segment lengths [m]
s0  = [0; cumsum(seg)];                          % cumulative distance along raw ring
Lgeo = s0(end);

% Densify at fixed arc-length step (linear in lat/lon; step << 1 km so error is negligible)
n  = max(ceil(Lgeo / cfg.DENSIFY_STEP_M), 2);
s  = linspace(0, Lgeo, n + 1)';
[s0u, iu] = unique(s0);
lat = interp1(s0u, ring(iu,1), s);
lon = interp1(s0u, ring(iu,2), s);

L_m  = Lgeo * cfg.SLACK_FACTOR;
fibre.lat = lat;  fibre.lon = lon;  fibre.s_m = s * cfg.SLACK_FACTOR;
fibre.L_geo_km    = Lgeo / 1e3;
fibre.L_km        = L_m / 1e3;
fibre.N_IU        = cfg.m.N_DAS_int;                  % formula value (map_params.m); final count set by the placement below
if abs(L_m - cfg.m.L_fibre) > 1, warning('L_boundary (map_params) differs from compute_fibre by %.1f m.', L_m - cfg.m.L_fibre); end
fibre.N_sensing   = round(L_m / cfg.SPATIAL_RES_M);   % sensing points = L / spatial resolution
fibre.N_samples   = round(L_m / cfg.CH_SPACING_M);    % channel samples = L / channel spacing

% Placement (two directions per site): each interrogator uses N_ch_active = 2 channels, one in each direction along the
% boundary; channels 3-4 are spare (redundancy / possible double coverage in Hot zones) and get NO sensing segment.
% The ring is split into N equal arcs, the site sits at the middle of its arc (lead-in = m.L_leadin, 0 while the shelter is on the boundary) and each of
% its two channels senses half an arc. Every channel's total fibre = lead-in + sensing length must be <= R_DAS; if the
% geometry fails this, sites are added until it passes (and the extra count is reported).
nact = cfg.N_CH_ACTIVE;  N = cfg.m.N_DAS_int;
at = @(u) 1 + mod(round(u * n), n);                       % index on the closed ring for arc fraction u (0..1)
assert(cfg.m.L_leadin / 1e3 < cfg.R_CH_KM, 'Lead-in (%.2f km) leaves no sensing range within R_DAS = %g km.', cfg.m.L_leadin / 1e3, cfg.R_CH_KM);
while true
    nSeg = N * nact;
    site = zeros(N, 1);  sa = zeros(nSeg, 1);  sb = sa;  sSite = sa;  nearIdx = sa;  farIdx = sa;  dirn = sa;  leadin = sa;
    for g = 1:N
        u0 = (g - 1) / N;  uS = u0 + 0.5 / N;  site(g) = at(uS);
        for j = 1:nact
            q = (g - 1) * nact + j;
            ua = u0 + (j - 1) / (N * nact);  ub = u0 + j / (N * nact);      % segment spans arc fractions [ua, ub]
            if j == 1, nearIdx(q) = at(ub); farIdx(q) = at(ua); dirn(q) = -1;   % channel 1: one direction from the site
            else,      nearIdx(q) = at(ua); farIdx(q) = at(ub); dirn(q) = +1; end   % channel 2: the other direction
            sa(q) = ua * fibre.L_km;  sb(q) = ub * fibre.L_km;  sSite(q) = g;
            leadin(q) = cfg.m.L_leadin / 1e3;               % lead-in fibre shelter -> boundary [km] (0 while the shelter is on the boundary)
        end
    end
    need = (sb - sa) + leadin;                              % total fibre per channel [km]
    if all(need <= cfg.R_CH_KM + 1e-9), break; end
    N = N + 1;                                              % geometry fails: add a site
end
extra = N - cfg.m.N_DAS_int;
fibre.segMarginKm = cfg.R_CH_KM - need;                   % remaining range margin per channel [km]
fprintf('Channel margin  : R_DAS - (lead-in + sensing) per channel [km]: %s\n', strjoin(compose('%.2f', fibre.segMarginKm(:)'), ', '));
if extra > 0, warning('PLACEMENT:EXTRA', 'Placement needed %d extra interrogator(s): set m.N_DAS_int_extra = %d in map_params.m.', extra, extra); end
assert(all(need <= cfg.R_CH_KM + 1e-9), 'A sensing channel exceeds R_DAS (%.2f km > %g km).', max(need), cfg.R_CH_KM);
fibre.N_IU = N;  fibre.nSeg = nSeg;  fibre.N_ch_spare = cfg.m.N_ch_spare;
fibre.iuIdx = site;   fibre.iuLat = lat(site);  fibre.iuLon = lon(site);
fibre.iuSpanKm = fibre.L_km / N;                          % boundary length served by one interrogator
fibre.segSite = sSite;  fibre.segNearIdx = nearIdx;  fibre.segFarIdx = farIdx;  fibre.segDir = dirn;
fibre.segLenKm = (sb - sa);  fibre.segFeederKm = leadin;  fibre.segNeedKm = need;
fibre.segOverRange = need > cfg.R_CH_KM + 1e-9;


% Enclosed area (planar, equal-area-ish check against ~556 km^2 from Attar & Dhieb)
y = deg2rad(lat - mean(lat)) * R;  x = deg2rad(lon - mean(lon)) * R * cosd(mean(lat));
fibre.area_km2 = abs(polyarea(x, y)) / 1e6;
end

function d = hav(a, b, R)
dlat = deg2rad(b(:,1) - a(:,1));  dlon = deg2rad(b(:,2) - a(:,2));
h = sin(dlat/2).^2 + cosd(a(:,1)) .* cosd(b(:,1)) .* sin(dlon/2).^2;
d = 2 * R * asin(min(1, sqrt(h)));
end
