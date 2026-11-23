function scene = build_scene(cfg)
% BUILD_SCENE  Single source of truth shared by every output (both themes, static and interactive).
rng(cfg.seed);
scene.cfg = cfg;   scene.th = cfg.theme;
T = load_terrain(cfg);   scene.T = T;
F = compute_fibre(cfg);
F.x = smooth_ring(T.toX(F.lon), 15);   F.y = smooth_ring(T.toY(F.lat), 15);   F.s_km = F.s_m / 1000;
% (x, y) are smoothed over ~300 m for DISPLAY only; L and N_IU use the raw polygon (compute_fibre).

% Fibre height: lifted above a ridge-dilated copy of the display mesh so it is never hidden.
Zd = imdilate(T.base.Z, strel('disk', cfg.fibreDilateCells));
G  = griddedInterpolant({T.base.Y(:,1), T.base.X(1,:)}, Zd, 'linear', 'nearest');
zf = movmean(G(F.y, F.x), 15);
F.z = max(zf, T.heightXY(F.x, F.y)) + cfg.fibreLift;
F.iuX = F.x(F.iuIdx);   F.iuY = F.y(F.iuIdx);   F.iuZ = F.z(F.iuIdx);
segEnd = unique([F.segNearIdx; F.segFarIdx]);                                   % segment ends (shared ends drawn once)
F.segEndX = F.x(segEnd);   F.segEndY = F.y(segEnd);   F.segEndZ = F.z(segEnd);
poly.x = F.x;   poly.y = F.y;

% Infrastructure (PROPOSED placements) and weak-coverage risk (OSM roads + DEM + directional CCTV model)
fetch_roads_osm();
roads = getfield(load(fullfile(cfg.dataDir, 'roads_osm.mat')), 'roads');
A = compute_assets(cfg, T, F, roads, poly);
R = compute_risk(cfg, T, F, roads, A.cctv);

% phi-OTDR simulator output (github.com/aljoudm/DAS-Simulation, main.m defaults), see SOURCES.md
scene.sim = getfield(load(cfg.simFile), 'sim');
sim = scene.sim;
% Detection threshold: the simulator's rule median + 8*1.4826*MAD, evaluated over the ONE channel the system monitors (z <= channel
% length). The importer's full-profile value is kept as sim.thr_full; no simulated number is altered.
Lch0 = max(F.segNeedKm) * 1e3;   kk = sim.z <= Lch0;   mdn = median(sim.a(kk));
sim.thr_full = sim.thr;   sim.thr = mdn + 8 * 1.4826 * median(abs(sim.a(kk) - mdn));   sim.median_full = sim.median;   sim.median = mdn;
for e = sim.events, if e.z0 <= Lch0 && e.peak_nm <= sim.thr, warning('Event "%s" (%.2f nm) is below the channel threshold %.2f nm.', e.name, e.peak_nm, sim.thr); end, end
scene.sim = sim;
isCal = strcmp([sim.events.type], "sine");                    % calibration sine is not a field event
ref = max([sim.events(~isCal).peak_nm]);                      % colour-scale reference [nm]
scene.energyRef_nm = ref;   scene.thresholdNorm = sim.thr / ref;

% Events are placed INSIDE the computed high-risk zone (PROPOSED scenario)
roadsXY = arrayfun(@(r) struct('x', T.toX(r.lon), 'y', T.toY(r.lat)), roads);
[E, U] = place_events(cfg, T, F, poly, R, A, sim, roadsXY);
F.energy = fibre_energy(F, E, sim, ref);
scene.fibre = F;   scene.events = E;   scene.risk = R;
scene.uav = U;
d = hypot(A.patrol(:,1) - E.cross(1), A.patrol(:,2) - E.cross(2));
[~, A.patrolNearest] = min(d);
scene.assets = A;

H = readtable(cfg.holySitesCsv, 'TextType', 'string');
H.x = T.toX(H.lon);  H.y = T.toY(H.lat);  H.z = arrayfun(@(a,b) T.heightXY(a,b), H.x, H.y);
scene.sites = H;
scene.inset = choose_inset_rect(scene);
end

function [E, U] = place_events(cfg, T, F, poly, R, A, sim, roadsXY)
% Walking (simulated) = the intruder, placed at the highest-risk fibre point. The simulated vehicle is placed at the SAME
% separation along the fibre as in the simulated section (4 km -> 8 km), so the map keeps the simulated geometry; it is
% snapped to a major road (OSM) and kept clear of the UAV cones. Digging and the calibration sine are NOT placed on the map.
L = F.L_km;  s = F.s_km(:);  span = F.iuSpanKm;
sIU = s(F.iuIdx);
d = abs(s - sIU');  d = min(d, L - d);  dIU = min(d, [], 2);
rf = movmean(R.at(F.lat, F.lon), 51);               % risk along the fibre (~1 km window)
[~, dRoad] = knnsearch(A.roadPts, [F.x F.y]);        % distance fibre -> nearest major road [km]
names = [sim.events.name];
zW = sim.events(names == "Walking").z0 / 1e3;   zV = sim.events(names == "Vehicle").z0 / 1e3;   % positions in the simulated section [km]
% The simulated section is laid onto ONE physical FEBUS channel: z = 0 at the channel's near end (interrogator side), running
% along the channel (length Lch). Every imported event must lie inside the channel, otherwise stop and ask.
Lch = max(F.segNeedKm);
for e = sim.events, if e.z0 / 1e3 + 0.015 > Lch, error('Simulated event "%s" at %.2f km lies beyond the channel length %.2f km: tell the project lead before placing it.', e.name, e.z0 / 1e3, Lch); end, end
nq = F.nSeg;   iW = zeros(nq, 1);   iV = zeros(nq, 1);
for q = 1:nq                                         % fibre index of walking / vehicle if the section sits on channel q
    s0 = s(F.segNearIdx(q));
    dd = abs(s - mod(s0 + F.segDir(q) * zW, L));  dd = min(dd, L - dd);  [~, iW(q)] = min(dd);
    dd = abs(s - mod(s0 + F.segDir(q) * zV, L));  dd = min(dd, L - dd);  [~, iV(q)] = min(dd);
end
[~, ord] = sort(rf(iW), 'descend');                  % highest-risk walking point first
found = false;
for roadTol = [0.15 0.30 0.60]
    for qi = ord(:)'
        iInt = iW(qi);   j = iV(qi);   dirn = F.segDir(qi);
        if dRoad(j) > roadTol, continue; end
        E = struct('iInt', iInt, 'cross', [F.x(iInt) F.y(iInt) F.z(iInt)], 's_int', s(iInt));
        U = place_uavs(cfg, T, F, E, poly);
        if min(hypot(F.x(j) - [U.x], F.y(j) - [U.y])) < 4.5, continue; end      % vehicle clear of the UAV cones
        found = true;   break;
    end
    if found, break; end
end
if ~found, error('No channel puts the simulated vehicle within 600 m of a major road; tell the project lead.'); end
E.channel = qi;
E.iInt = iInt;  E.iVeh = j;  E.riskInt = rf(iInt);  E.roadDist_km = dRoad(j);
E.secDir = dirn;                                    % +1: simulated distance increases with the fibre arc length
E.secS0 = s(F.segNearIdx(qi));                      % fibre arc position of simulated distance 0 = channel near end [km]
E.secLen = Lch;                                     % the section shown = one channel [km] (the simulation is longer: sim.params.L_m)

[nx, ny] = outward_normal(F, iInt, poly);
tx = -ny;  ty = nx;
t = linspace(0, 1, 70)';
dist = 3.4 * (1 - t) + 0.14;
lat = 0.28 * sin(2*pi*1.4*t + 0.7) .* (1 - t);
E.trackX = F.x(iInt) + nx * dist + tx * lat;
E.trackY = F.y(iInt) + ny * dist + ty * lat;
E.trackZ = T.heightXY(E.trackX, E.trackY) + 0.05;
E.intruder = [E.trackX(end) E.trackY(end) E.trackZ(end)];

[~, kk] = min(hypot(A.roadPts(:,1) - F.x(j), A.roadPts(:,2) - F.y(j)));          % vehicle sits ON the nearest road point
E.vehicle      = [A.roadPts(kk, :), T.heightXY(A.roadPts(kk,1), A.roadPts(kk,2)) + 0.06];
E.vehicleFibre = [F.x(j) F.y(j) F.z(j)];
E.s_veh = s(j);
E.roadLines = {};                                   % the road(s) the vehicle is on, +-3.5 km around it
for k = 1:numel(roadsXY)
    near = hypot(roadsXY(k).x - E.vehicle(1), roadsXY(k).y - E.vehicle(2)) < 3.5;
    if ~any(near), continue; end
    xr = roadsXY(k).x;  yr = roadsXY(k).y;   xr(~near) = NaN;   yr(~near) = NaN;
    E.roadLines{end+1} = [xr, yr, T.heightXY(xr, yr) + 0.05]; %#ok<AGROW>
end
E.peak_int_nm = sim.events(names == "Walking").peak_nm;      % simulated peak activity of the two event types
E.peak_veh_nm = sim.events(names == "Vehicle").peak_nm;
end

function e = fibre_energy(F, E, sim, ref)
% Normalised activity along the fibre for COLOURING only: uniform quiet level = the simulator's median
% background activity; the two events carry their simulated peak activity. Hot-spot width (sigma 0.8 km)
% is widened for visibility (the simulated events are ~30 m wide). No random texture is added.
s = F.s_km(:);  L = F.L_km;
g = @(s0, sig) exp(-0.5 * (min(abs(s - s0), L - abs(s - s0)) / sig).^2);
base = sim.median / ref;
e = base + (E.peak_int_nm / ref - base) * g(E.s_int, 0.8) + (E.peak_veh_nm / ref - base) * g(E.s_veh, 0.8);
e = min(max(e, 0), 1);
end

function U = place_uavs(cfg, T, F, E, poly)
L = F.L_km;  s = F.s_km(:);
off = [0.12 0.42 0.74];   U = struct('x', {}, 'y', {}, 'z', {}, 'gz', {});
for k = 1:cfg.nUAV
    sT = mod(E.s_int + off(k) * L, L);
    dIU = abs(s(F.iuIdx) - sT);   dIU = min(dIU, L - dIU);
    if min(dIU) < 6, sT = mod(sT + 8, L); end              % keep UAVs clear of the IU labels
    [~, i] = min(abs(s - sT));
    for tries = 1:8                                          % keep UAVs (and their cones) out of the Mashaer inset area
        if F.lon(i) > cfg.insetSearchLon(1) - 0.03 && F.lon(i) < cfg.insetSearchLon(2) + 0.03 && ...
           F.lat(i) > cfg.insetSearchLat(1) - 0.03 && F.lat(i) < cfg.insetSearchLat(2) + 0.03
            sT = mod(sT + 6, L);   [~, i] = min(abs(s - sT));
        else, break; end
    end
    [nx, ny] = outward_normal(F, i, poly);
    x = F.x(i) - 1.0 * nx;  y = F.y(i) - 1.0 * ny;           % 1 km inside the perimeter
    gz = T.heightXY(x, y);
    U(k) = struct('x', x, 'y', y, 'z', gz + cfg.uavAlt, 'gz', gz);
end
[~, nearest] = min(arrayfun(@(u) hypot(u.x - E.cross(1), u.y - E.cross(2)), U));
for k = 1:numel(U), U(k).responding = (k == nearest); end
end

function v = smooth_ring(v, w)
% Moving average on a closed ring (wrap-around padding), same length as input.
v = v(:);  h = floor(w / 2);
p = movmean([v(end-h+1:end); v; v(1:h)], w);
v = p(h+1:end-h);
end
