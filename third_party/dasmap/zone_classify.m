function Z = zone_classify(m, ring, G, cs)
% ZONE_CLASSIFY  Square cells of side cs [m] crossed by the boundary; small edge cells merged into the neighbour that continues the
% boundary; cell risk = P90 of the DEM-grid intrinsic risk inside the (merged) cell; k-means (k = 3) thresholds R_cold / R_hot; zone
% per cell; per-cell lambda (the Sheet lambda is per ZONE per day, spread over the cells of the zone in proportion to
% risk_cell * boundary_length_cell). ring = [lat lon] closed boundary; G from intrinsic_risk_grid.
x = (ring(:,2) - G.lon0) * G.kx;   y = (ring(:,1) - G.lat0) * G.ky;
% --- densify the boundary: ordered pieces with their length and the square they fall in
seg = hypot(diff(x), diff(y));   mx = []; my = []; ml = [];
for i = 1:numel(seg)
    n = max(ceil(seg(i) / m.zone_step_m), 1);   t = ((1:n)' - 0.5) / n;
    mx = [mx; x(i) + t * (x(i+1) - x(i))];  my = [my; y(i) + t * (y(i+1) - y(i))];  ml = [ml; repmat(seg(i) / n, n, 1)]; %#ok<AGROW>
end
x0 = floor(min([x; G.x(:)]) / cs) * cs;   y0 = floor(min([y; G.y(:)]) / cs) * cs;
NX = ceil((max([x; G.x(:)]) - x0) / cs) + 1;   NY = ceil((max([y; G.y(:)]) - y0) / cs) + 1;
cid = @(px, py) (floor((py - y0) / cs)) * NX + floor((px - x0) / cs) + 1;
bid = cid(mx, my);                                               % square id of each boundary piece, in boundary order
Lsq = accumarray(bid, ml, [NX * NY 1]);
sq = find(Lsq > 0);   nSq = numel(sq);                           % ONLY squares crossed by the boundary
% --- merge edge squares with boundary length < min_cell_frac * cs into the neighbour that continues the boundary
lab = (1:NX * NY)';   thr = m.min_cell_frac * cs;   nSmall0 = nnz(Lsq > 0 & Lsq < thr);
seq = bid(:);
while true
    glen = accumarray(lab(bid), ml, [NX * NY 1]);
    small = find(glen > 0 & glen < thr);   if isempty(small), break; end
    [~, o] = sort(glen(small));   small = small(o);
    s = lab(seq);   did = false;
    for g = small'
        idx = find(s == g);
        nb = [s(mod(idx - 2, numel(s)) + 1); s(mod(idx, numel(s)) + 1)];   nb = nb(nb ~= g);   % previous / next along the boundary
        if isempty(nb), continue; end
        [~, j] = max(glen(nb));   lab(lab == g) = nb(j);   did = true;   break;
    end
    if ~did, break; end
end
ulab = unique(lab(sq));   ng = numel(ulab);
gidx = zeros(NX * NY, 1);   [~, loc] = ismember(lab(sq), ulab);   gidx(sq) = loc;     % square id -> merged-cell index
Lc = accumarray(gidx(bid), ml, [ng 1]);
nsqIn = accumarray(loc, 1, [ng 1]);
% --- cell risk: percentile of the pixel risk inside the (merged) cell
pidx = gidx(cid(G.x(:), G.y(:)));   ok = pidx > 0;
cellRisk = double(accumarray(pidx(ok), G.risk(ok), [ng 1], @(v) prctile(v, m.cell_risk_pct)));   % double: the lambda sums below must be exact
if any(accumarray(pidx(ok), 1, [ng 1]) == 0), error('zone_classify:nodem', 'Cells without DEM pixels.'); end
% --- k-means thresholds
rng(m.zone_seed);
[~, C] = kmeans(cellRisk, m.zone_k, 'Replicates', m.zone_kmeans_replicates, 'Start', 'plus');
C = sort(C(:));
Z.R_cold = mean(C(1:2));   Z.R_hot = mean(C(2:3));   Z.centres = C;
zone = ones(ng, 1);   zone(cellRisk >= Z.R_cold) = 2;   zone(cellRisk >= Z.R_hot) = 3;      % 1 Cold, 2 Neutral, 3 Hot
% --- per-cell lambda (events/day): zone lambda spread over the zone's cells in proportion to risk * boundary length
rg = {m.lambda_cold_range, m.lambda_neutral_range, m.lambda_hot_range};
lam = zeros(ng, 3);   w = cellRisk .* Lc;                           % columns: min, mid, max
for z = 1:3
    in = zone == z;   if ~any(in), continue; end
    lam(in, :) = (w(in) / sum(w(in))) * [rg{z}(1), mean(rg{z}), rg{z}(2)];
    chk = sum(lam(in, :), 1) - [rg{z}(1), mean(rg{z}), rg{z}(2)];
    if any(abs(chk) > 1e-9), error('zone_classify:lambda', 'Per-zone lambda sum differs from the zone lambda (zone %d, cs %g): %s vs %s', z, cs, mat2str(sum(lam(in, :), 1)), mat2str([rg{z}(1), mean(rg{z}), rg{z}(2)])); end
end
% --- outputs
cy = floor((sq - 1) / NX);   cx = (sq - 1) - cy * NX;               % square column / row indices
sqx = x0 + (cx + 0.5) * cs;   sqy = y0 + (cy + 0.5) * cs;           % square centres [m]
Z.cs = cs;   Z.nCells = ng;   Z.nSquares = nSq;   Z.nSmall0 = nSmall0;   Z.nMerged = nSq - ng;
Z.sqx_m = sqx;   Z.sqy_m = sqy;   Z.sqCell = loc;                   % squares: centres and the merged-cell index each belongs to
Z.cx_m = accumarray(loc, Lsq(sq) .* sqx, [ng 1]) ./ accumarray(loc, Lsq(sq), [ng 1]);     % cell centre = boundary-length-weighted mean of its squares
Z.cy_m = accumarray(loc, Lsq(sq) .* sqy, [ng 1]) ./ accumarray(loc, Lsq(sq), [ng 1]);
Z.lat = G.lat0 + Z.cy_m / G.ky;   Z.lon = G.lon0 + Z.cx_m / G.kx;
Z.id = (1:ng)';   Z.nsq = nsqIn;   Z.Lc_m = Lc;   Z.risk = cellRisk;   Z.zone = zone;   Z.lambda = lam;
Z.cameras = Lc / m.Cov_CCTV;                                         % info only
Z.nZone = arrayfun(@(z) nnz(zone == z), 1:3);                        % [Cold Neutral Hot]
Z.kmZone = arrayfun(@(z) sum(Lc(zone == z)) / 1e3, 1:3);
Z.L_total_km = sum(ml) / 1e3;
Z.lambdaZone = [rg{1}; rg{2}; rg{3}];                                % per zone [min max], events/day
Z.lambdaSum = arrayfun(@(z) sum(lam(zone == z, :), 1), 1:3, 'UniformOutput', false);   % per-zone sums (check)
end
