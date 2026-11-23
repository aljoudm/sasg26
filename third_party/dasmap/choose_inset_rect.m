function I = choose_inset_rect(scene)
% CHOOSE_INSET_RECT  The inset area is a plain lat/lon rectangle around the Mashaer. Its edges are searched on a
% grid so that (i) the sites cfg.insetSites (and their labels) lie inside with a margin, (ii) no edge passes through
% (or too close to) an icon, CCTV wedge, UAV cone, event marker or response line; the fibre itself may cross the edges.
% Clearances are measured in the SAME oblique orthographic screen geometry the inset uses (u = x, v = y*sin(el) + z*cos(el)),
% so object heights (UAVs, labels, mountains) are taken into account; the frame is a flat rectangle at height zf.
I = search_rect(scene, 1.0, 1.6);                           % first try: icon clearance 1.0 km, CCTV wedge (range + 0.2 km) kept whole
if I.clearance < 1, I = search_rect(scene, 0.7, 0.7); end   % fallback: icons only
if I.clearance < 1, I = search_rect(scene, 0.5, 0.5); end   % last resort: icon centres only
if I.clearance < 1
    warning('INSET:CLEARANCE', 'Best inset rectangle has clearance ratio %.2f (<1): an edge passes close to "%s".', I.clearance, I.limiting);
end
fprintf('Inset rectangle : lon %.3f-%.3f, lat %.3f-%.3f (%.1f x %.1f km), clearance ratio %.2f, aspect %.2f\n', ...
    I.lon, I.lat, diff(I.x), diff(I.y), I.clearance, I.aspect);
end

function I = search_rect(scene, reqIcon, reqCctv)
cfg = scene.cfg;  T = scene.T;  A = scene.assets;  E = scene.events;  F = scene.fibre;  S = scene.sites;
sinEl = sind(cfg.insetEl);   cosEl = cosd(cfg.insetEl);
scr = @(x, y, z) [x, y * sinEl + z * cosEl];                  % oblique orthographic screen coordinates [km]
hz = @(x, y) arrayfun(@(a, b) T.heightXY(a, b), x, y);        % terrain height (display units)

% obstacles: [u v required-clearance-km], with a label for diagnostics (heights included)
O = [scr(A.entry(:,1), A.entry(:,2), A.entry(:,3)), reqIcon * ones(size(A.entry,1), 1)];         lab = repmat("entry", size(A.entry,1), 1);
cx = [A.cctv.x]';  cy = [A.cctv.y]';
O = [O; scr(cx, cy, hz(cx, cy)), reqCctv * ones(numel(cx), 1)];                                  lab = [lab; repmat("cctv", numel(cx), 1)];
O = [O; scr(A.patrol(:,1), A.patrol(:,2), A.patrol(:,3)), reqIcon * ones(size(A.patrol,1), 1)];  lab = [lab; repmat("patrol", size(A.patrol,1), 1)];
O = [O; scr(F.iuX, F.iuY, F.iuZ + 2.0), 1.2 * ones(numel(F.iuX), 1)];                            lab = [lab; repmat("IU", numel(F.iuX), 1)];
O = [O; scr(A.c2(1), A.c2(2), A.c2(3) + 1.5), 1.0];                                              lab = [lab; "C2"];
ux = [scene.uav.x]';  uy = [scene.uav.y]';  uz = [scene.uav.z]';
O = [O; scr(ux, uy, uz), (cfg.uavConeR + 0.8) * ones(numel(ux), 1)];                             lab = [lab; repmat("UAV", numel(ux), 1)];
O = [O; scr(E.cross(1), E.cross(2), E.cross(3)), 2.6; scr(E.intruder(1), E.intruder(2), E.intruder(3) + 1.0), 2.6; ...
        scr(E.vehicle(1), E.vehicle(2), E.vehicle(3) + 1.0), 1.5];                               lab = [lab; "cross"; "intruder"; "vehicle"];
u = scene.uav([scene.uav.responding]);   t = linspace(0, 1, 40)';
seg = {[u.x + (E.cross(1) - u.x) * t, u.y + (E.cross(2) - u.y) * t, u.z + (E.intruder(3) + 0.3 - u.z) * t - 0.25 * sin(pi * t)]};   % UAV response arc
p = A.patrol(A.patrolNearest, :);   px = p(1) + (E.cross(1) - p(1)) * t;   py = p(2) + (E.cross(2) - p(2)) * t;
seg{end+1} = [px, py, hz(px, py) + 0.07];                                                         % patrol response line
seg{end+1} = [E.trackX, E.trackY, E.trackZ];                                                       % intruder track
for k = 1:numel(seg), O = [O; scr(seg{k}(:,1), seg{k}(:,2), seg{k}(:,3)), 0.7 * ones(size(seg{k}, 1), 1)]; lab = [lab; repmat("line", size(seg{k}, 1), 1)]; end %#ok<AGROW>

% sites (ground) and the top of their labels (z + 3 + dz + ~0.6)
isS = ismember(S.name, cfg.insetSites);
sx = S.x(isS);  sy = S.y(isS);  sz = S.z(isS);  sdz = S.dz(isS);
sBase = scr(sx, sy, sz);                       % site markers
sTop  = scr(sx + S.dx(isS), sy, sz + (3.0 + sdz) * cfg.insetLabelScale + 0.7);   % label tops
margin = cfg.insetMargin_km;   marginTop = cfg.insetMarginTop_km;

% coarse terrain maxima (block max) for the frame height of each candidate
bl = 10;   Zc = T.base.Z;  [ny, nx] = size(Zc);   ny2 = floor(ny / bl) * bl;   nx2 = floor(nx / bl) * bl;
Zb = squeeze(max(max(reshape(Zc(1:ny2, 1:nx2), bl, ny2 / bl, bl, nx2 / bl), [], 1), [], 3));
Xb = T.base.X(1, bl/2:bl:nx2);   Yb = T.base.Y(bl/2:bl:ny2, 1);
aspectTarget = cfg.insetAspect;

st = 0.0025;
lonW = cfg.insetSearchLon(1):st:cfg.insetSearchLon(1) + 0.045;      lonE = cfg.insetSearchLon(2) - 0.045:st:cfg.insetSearchLon(2);
latS = cfg.insetSearchLat(1):st:cfg.insetSearchLat(1) + 0.04;       latN = cfg.insetSearchLat(2) - 0.05:st:cfg.insetSearchLat(2);
best = -inf;   I = struct();
for w = lonW, for e = lonE, for s0 = latS, for n = latN
    x1 = T.toX(w);  x2 = T.toX(e);  y1 = T.toY(s0);  y2 = T.toY(n);
    zf = max(max(Zb(Yb >= y1 & Yb <= y2, Xb >= x1 & Xb <= x2))) + 0.4;
    v1 = y1 * sinEl + zf * cosEl;   v2 = y2 * sinEl + zf * cosEl;                          % frame edges on screen
    if min([sBase(:,1) - x1; x2 - sBase(:,1); sBase(:,2) - v1; v2 - sTop(:,2); sTop(:,1) - x1; x2 - sTop(:,1)]) < 0 ...
       || min([sBase(:,1) - x1; x2 - sBase(:,1); sBase(:,2) - v1]) < margin || min(v2 - sTop(:,2)) < marginTop - 3.4
        continue;                                                                          % sites + labels inside with margin
    end
    d = min([dseg(O(:,1:2), [x1 v1], [x2 v1]), dseg(O(:,1:2), [x2 v1], [x2 v2]), ...
             dseg(O(:,1:2), [x2 v2], [x1 v2]), dseg(O(:,1:2), [x1 v2], [x1 v1])], [], 2);   % distance to the nearest edge
    [ratio, iw] = min(d ./ O(:,3));                             % >= 1 means every edge keeps its clearance
    asp = (x2 - x1) / (v2 - v1);
    score = min(ratio, 1.5) - 0.35 * abs(log(asp / aspectTarget));
    if score > best
        best = score;
        I = struct('lon', [w e], 'lat', [s0 n], 'x', [x1 x2], 'y', [y1 y2], 'aspect', asp, 'clearance', ratio, 'limiting', lab(iw), 'zf', zf);
    end
end, end, end, end
if isempty(fieldnames(I)), error('No inset rectangle satisfies the site margins.'); end
end

function d = dseg(P, a, b)
% Distance from points P (N x 2) to the segment a-b.
ab = b - a;   t = ((P(:,1) - a(1)) * ab(1) + (P(:,2) - a(2)) * ab(2)) / (ab * ab');
t = min(max(t, 0), 1);
d = hypot(P(:,1) - (a(1) + t * ab(1)), P(:,2) - (a(2) + t * ab(2)));
end
