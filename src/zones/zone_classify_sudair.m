function Z = zone_classify_sudair(m, ring, G, cs, sub_xy, R_hot_sub)
% ZONE_CLASSIFY_SUDAIR  Adapted from DAS-map zone_classify.m (third_party/dasmap, a25fd0c). Same cell construction (squares of side cs
% crossed by the boundary, small edge cells merged, cell risk = P90 of the intrinsic risk), with ONE change for a power plant:
%   Hot = forced class: any cell whose boundary comes within R_hot_sub of the substation polygon (sub_xy = [x y] in the local frame).
%   The remaining cells are split by the DAS-map k-means (k = m.zone_k, here 2) into Cold / Neutral.
% Lambda (events/day) is NOT taken from Makkah: Z.lambda is NaN and written as "TBD" by the caller.
x = (ring(:,2) - G.lon0) * G.kx;   y = (ring(:,1) - G.lat0) * G.ky;
seg = hypot(diff(x), diff(y));   mx = []; my = []; ml = [];
for i = 1:numel(seg)
    n = max(ceil(seg(i) / m.zone_step_m), 1);   t = ((1:n)' - 0.5) / n;
    mx = [mx; x(i) + t * (x(i+1) - x(i))];  my = [my; y(i) + t * (y(i+1) - y(i))];  ml = [ml; repmat(seg(i) / n, n, 1)]; %#ok<AGROW>
end
dsub = dist_to_poly(mx, my, sub_xy(:,1), sub_xy(:,2));            % distance of every boundary piece to the substation polygon [m]
x0 = floor(min([x; G.x(:)]) / cs) * cs;   y0 = floor(min([y; G.y(:)]) / cs) * cs;
NX = ceil((max([x; G.x(:)]) - x0) / cs) + 1;   NY = ceil((max([y; G.y(:)]) - y0) / cs) + 1;
cid = @(px, py) (floor((py - y0) / cs)) * NX + floor((px - x0) / cs) + 1;
bid = cid(mx, my);
Lsq = accumarray(bid, ml, [NX * NY 1]);
sq = find(Lsq > 0);   nSq = numel(sq);
lab = (1:NX * NY)';   thr = m.min_cell_frac * cs;   nSmall0 = nnz(Lsq > 0 & Lsq < thr);
seq = bid(:);
while true
    glen = accumarray(lab(bid), ml, [NX * NY 1]);
    small = find(glen > 0 & glen < thr);   if isempty(small), break; end
    [~, o] = sort(glen(small));   small = small(o);
    s = lab(seq);   did = false;
    for g = small'
        idx = find(s == g);
        nb = [s(mod(idx - 2, numel(s)) + 1); s(mod(idx, numel(s)) + 1)];   nb = nb(nb ~= g);
        if isempty(nb), continue; end
        [~, j] = max(glen(nb));   lab(lab == g) = nb(j);   did = true;   break;
    end
    if ~did, break; end
end
ulab = unique(lab(sq));   ng = numel(ulab);
gidx = zeros(NX * NY, 1);   [~, loc] = ismember(lab(sq), ulab);   gidx(sq) = loc;
Lc = accumarray(gidx(bid), ml, [ng 1]);
nsqIn = accumarray(loc, 1, [ng 1]);
pidx = gidx(cid(G.x(:), G.y(:)));   ok = pidx > 0;
cellRisk = double(accumarray(pidx(ok), G.risk(ok), [ng 1], @(v) prctile(v, m.cell_risk_pct)));
if any(accumarray(pidx(ok), 1, [ng 1]) == 0), error('zone_classify:nodem', 'Cells without DEM pixels.'); end
% --- Hot = forced (substation + HV yard); k-means on the rest
dCell = accumarray(gidx(bid), dsub, [ng 1], @min);
isHot = dCell <= R_hot_sub;
rng(m.zone_seed);
rest = cellRisk(~isHot);
zone = 3 * ones(ng, 1);
if numel(rest) >= m.zone_k
    [~, C] = kmeans(rest, m.zone_k, 'Replicates', m.zone_kmeans_replicates, 'Start', 'plus');
    C = sort(C(:));  Z.R_cold = mean(C(1:2));  Z.centres = C;
    zone(~isHot) = 1 + (cellRisk(~isHot) >= Z.R_cold);              % 1 Cold, 2 Neutral
else
    Z.R_cold = NaN;  Z.centres = [];  zone(~isHot) = 2;
end
Z.R_hot = NaN;                                                      % Hot is forced by distance, not by a risk threshold
cy = floor((sq - 1) / NX);   cx = (sq - 1) - cy * NX;
sqx = x0 + (cx + 0.5) * cs;   sqy = y0 + (cy + 0.5) * cs;
Z.cs = cs;   Z.R_hot_sub = R_hot_sub;   Z.nCells = ng;   Z.nSquares = nSq;   Z.nSmall0 = nSmall0;   Z.nMerged = nSq - ng;
Z.sqx_m = sqx;   Z.sqy_m = sqy;   Z.sqCell = loc;
Z.cx_m = accumarray(loc, Lsq(sq) .* sqx, [ng 1]) ./ accumarray(loc, Lsq(sq), [ng 1]);
Z.cy_m = accumarray(loc, Lsq(sq) .* sqy, [ng 1]) ./ accumarray(loc, Lsq(sq), [ng 1]);
Z.lat = G.lat0 + Z.cy_m / G.ky;   Z.lon = G.lon0 + Z.cx_m / G.kx;
Z.id = (1:ng)';   Z.nsq = nsqIn;   Z.Lc_m = Lc;   Z.risk = cellRisk;   Z.zone = zone;   Z.dSub_m = dCell;
Z.lambda = NaN(ng, 3);                                              % PLACEHOLDER: no Sudair intrusion-rate source
Z.nZone = arrayfun(@(z) nnz(zone == z), 1:3);                       % [Cold Neutral Hot]
Z.kmZone = arrayfun(@(z) sum(Lc(zone == z)) / 1e3, 1:3);
Z.L_total_km = sum(ml) / 1e3;
Z.piece = struct('x', mx, 'y', my, 'cell', gidx(bid));              % boundary pieces in order (for colouring the fibre by zone)
end

function d = dist_to_poly(px, py, vx, vy)
% Distance from points to a closed polygon (0 inside).
d = inf(size(px));  n = numel(vx);
for k = 1:n
    k2 = mod(k, n) + 1;  ax = vx(k); ay = vy(k); bx = vx(k2); by = vy(k2);
    dx = bx - ax; dy = by - ay; L2 = dx^2 + dy^2;
    t = 0; if L2 > 0, t = min(max(((px - ax) * dx + (py - ay) * dy) / L2, 0), 1); end
    d = min(d, hypot(px - (ax + t * dx), py - (ay + t * dy)));
end
d(inpolygon(px, py, vx, vy)) = 0;
end
