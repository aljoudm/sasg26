function sc = build_twin_scene(themeName)
% BUILD_TWIN_SCENE  One scene for the restyled twin (main + zoom). Real data only: Copernicus DEM, Esri imagery, OSM, our placement /
% zones / scenario and the Stage F engine profile. Display choices: src/viz/sasg_viz_params.m.
if nargin < 1, themeName = 'light'; end
c = sasg_config();  cfg = viz_cfg(themeName);  vp = sasg_viz_params();
cfg.pulseLenKm = vp.pulseLenKm;  cfg.pulseSpacingKm = vp.pulseSpacingKm;  cfg.pulsePhase = vp.pulsePhase;  cfg.fibreLift = vp.fibreLift;
cfg.col.riskLo = [1.00 0.75 0.15];  cfg.col.riskHi = [0.85 0.10 0.60];  cfg.col.c2 = [1 0.8 0.2];  cfg.col.entry = [1 1 1];  cfg.col.uav = [1 1 1];  cfg.col.patrol = [1 1 1];
tcfg = make_shaded_textures();  tcfg.imageryCredit = cfg.imageryCredit;
T = load_terrain(tcfg);
F0 = load(fullfile(c.resDir, 'placement.mat')).F;  Sc = load(fullfile(c.resDir, 'scenario.mat')).Sc;
Zs = load(fullfile(c.zonesDir, 'zones.mat'));  S = run_das_sudair();
n = F0.n;  X = T.toX(F0.lon);  Y = T.toY(F0.lat);
% fibre height: lifted above a ridge-dilated copy of the display mesh (DAS-map build_scene.m rule)
Zd = imdilate(T.base.Z, strel('disk', 2));  G = griddedInterpolant({T.base.Y(:, 1), T.base.X(1, :)}, Zd, 'linear', 'nearest');
Zf = max(movmean(G(Y, X), 15), T.heightXY(X, Y)) + cfg.fibreLift;
% zone per fibre point (nearest zone boundary piece)
kzx = Zs.G.kx / 1e3;  kzy = Zs.G.ky / 1e3;  Zz = Zs.Z;
fxz = (F0.lon - Zs.G.lon0) * kzx;  fyz = (F0.lat - Zs.G.lat0) * kzy;
[~, nn] = min((fxz - Zz.piece.x' / 1e3) .^ 2 + (fyz - Zz.piece.y' / 1e3) .^ 2, [], 2);  zone = Zz.zone(Zz.piece.cell(nn));
% channel distance of every fibre point
step = F0.L_km * 1e3 / n;  chDist = nan(n, 1);  chId = zeros(n, 1);
for k = 1:2, idx = F0.ch(k).idx;  chDist(idx) = F0.lead_m + (0:numel(idx) - 1)' * step;  chId(idx) = k;  end
% energy along the two channels from the Stage F engine profile; events that are not located on the fence (calibration sine, digging) and the
% other channel's event are masked to the local median [ASSUMED: display only]; the red glow is widened by +-glowDilate_m [ASSUMED: display only]
tab = S.tab;  types = string({tab.type});  zt = @(ty) [tab(types == ty).z0];
act = S.act;  med = median(act);
e = nan(n, 1);
for k = 1:2
    a = act;
    if k == 1, other = zt("vehicle"); else, other = zt("walk"); end
    for zm = [zt("sine"), zt("dig"), other], a(abs(S.z - zm) < 100) = med; end
    m = chId == k;  e(m) = interp1(S.z, a, chDist(m), 'linear', 'extrap');
end
ref = max([tab(ismember(types, ["walk" "vehicle"])).peak_nm]);
en = min(e / ref, 1);  w = round(vp.glowDilate_m / step);
% isolated simulated noise spikes above the threshold away from the two mapped events are not drawn as alarms [ASSUMED: display only]; counted below
nearEv0 = (abs(chDist - Sc.intr.z_m) < 400 & chId == 1) | (abs(chDist - Sc.veh.z_m) < 400 & chId == Sc.veh.ch);
nFalse = nnz(en > S.thr / ref & ~nearEv0);  en(en > S.thr / ref & ~nearEv0) = 0.95 * S.thr / ref;
en3 = movmax([en; en; en], 2 * w + 1);  en = en3(n + 1:2 * n);
F.x = X;  F.y = Y;  F.z = Zf;  F.energy = en;  F.s_km = F0.s_m(:) / 1e3;  F.L_km = F0.L_km;  F.lead_m = F0.lead_m;
F.N_IU = F0.N_IU;  F.N_sensing = F0.N_sensing;  F.N_ch_active = F0.N_ch_active;  F.N_ch_spare = F0.N_ch_spare;  F.zone = zone;  F.n = n;
bx = T.toX(F0.building(2));  by = T.toY(F0.building(1));  bz = T.heightXY(bx, by);
F.iuIdx = F0.entryIdx;  F.iuX = bx;  F.iuY = by;  F.iuZ = bz;                       % interrogator at the building
far = [F0.ch(1).idx(end); F0.ch(2).idx(end)];  segEnd = unique([F0.entryIdx; far]);
F.segEndX = X(segEnd);  F.segEndY = Y(segEnd);  F.segEndZ = Zf(segEnd);
F.nSeg = 2;  F.segNearIdx = [F0.entryIdx; F0.entryIdx];  F.segFarIdx = far;  F.segDir = [1; -1];  F.segLenKm = F0.chLenKm(:);
% risk (zones' own intrinsic risk grid: slope + road distance), shown in a corridor around the fibre
S0 = load(tcfg.demMat);  latD = S0.lat(:);  lonD = S0.lon(:)';  risk = Zs.G.risk;  [nr, nc] = size(risk);
bw = false(nr, nc);  ii = min(max(round((latD(1) - F0.lat) / abs(latD(2) - latD(1))) + 1, 1), nr);  jj = min(max(round((F0.lon - lonD(1)) / abs(lonD(2) - lonD(1))) + 1, 1), nc);
bw(sub2ind([nr nc], ii, jj)) = true;  dpx = bwdist(bw) * Zs.G.pxM / 1e3;
fade = max(1 - dpx / vp.risk_corridor_km, 0);  inC = fade > 0;
cfg.riskShowFrom = prctile(risk(inC), 10);
alpha = 0.75 * min(max((risk - cfg.riskShowFrom) / 0.35, 0), 1) .* fade;
R.at = griddedInterpolant({flip(latD), lonD(:)}, flipud(risk), 'linear', 'nearest');
R.alphaAt = griddedInterpolant({flip(latD), lonD(:)}, flipud(alpha), 'linear', 'nearest');
% events (intruder = engine Walking, vehicle = engine Vehicle)
it = Sc.intr;  ix = X(it.idx);  iy = Y(it.idx);  iz = T.heightXY(ix, iy);  o = it.outward;
Rr = load(fullfile(c.dataDir, 'roads_osm.mat')).roads;  rd = Rr(Sc.veh.road_k);  rx = T.toX(rd.lon);  ry = T.toY(rd.lat);
vx = T.toX(Sc.veh.lon);  vy = T.toY(Sc.veh.lat);
tl = 0.80;  tx = ix + o(1) * linspace(tl, -0.35, 30)';  ty = iy + o(2) * linspace(tl, -0.35, 30)';
E.cross = [ix iy iz];  E.intruder = [tx(1) ty(1) T.heightXY(tx(1), ty(1))];  E.trackX = tx;  E.trackY = ty;  E.trackZ = T.heightXY(tx, ty) + 0.016;
E.vehicle = [vx vy T.heightXY(vx, vy)];  E.roadLines = {[rx ry T.heightXY(rx, ry) + 0.01]};  E.secLen = S.z(end) / 1e3;
sim.z = S.z;  sim.a = S.act;  sim.thr = S.thr;  sim.median = S.median;
sim.events = struct('name', {}, 'type', {}, 'z0', {}, 'peak_nm', {});
for i = 1:numel(tab), sim.events(i) = struct('name', string(tab(i).name), 'type', string(tab(i).type), 'z0', tab(i).z0, 'peak_nm', tab(i).peak_nm); end
sc.cfg = cfg;  sc.th = cfg.theme;  sc.T = T;  sc.fibre = F;  sc.events = E;  sc.risk = R;  sc.sim = sim;  sc.thresholdNorm = S.thr / ref;
sc.uav = struct('x', {}, 'y', {}, 'z', {}, 'responding', {});  sc.vp = vp;  sc.tcfg = tcfg;
sc.F0 = F0;  sc.Sc = Sc;  sc.Z = Zz;  sc.zone = zone;
Ssub = load(fullfile(c.dataDir, 'substations.mat')).S;  sub = Ssub([Ssub.id] == c.subWayId);  sc.sub.x = T.toX(sub.g(:, 2));  sc.sub.y = T.toY(sub.g(:, 1));
sc.S = S;  sc.refPk = ref;
sc.nFalse = nFalse;
fprintf('twin scene: thresholdNorm %.2f, fibre points above threshold away from the two events: %d\n', sc.thresholdNorm, sc.nFalse);
end
