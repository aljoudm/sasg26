function Sc = scenario_sudair()
% SCENARIO_SUDAIR  Where the simulated intruder and the non-threat vehicle are drawn, tied to the DAS engine events:
%   * intruder = engine "Walking" event: fence point at channel distance z_walk = 0.4 * L_channel (engine default), channel 1;
%   * vehicle  = engine "Vehicle" event: on an access road (OSM highway=service/secondary/primary/tertiary/unclassified) within 80 m of
%     the fence, outside the plant, whose fibre channel distance is closest to the engine default 0.8 * L_channel.
% The engine is re-run with these positions (run_das_sudair), so map and trace show the same events. [ASSUMED: ILLUSTRATIVE positions]
c = sasg_config();  F = load(fullfile(c.resDir, 'placement.mat')).F;
ky = 111195;  kx = ky * cosd(mean(F.lat));  lat0 = mean(F.lat);  lon0 = mean(F.lon);
fx = (F.lon - lon0) * kx;  fy = (F.lat - lat0) * ky;  step = F.L_km * 1e3 / F.n;
L = F.longestChannelKm * 1e3;  lead = F.lead_m;
chDist = nan(F.n, 1);  chId = zeros(F.n, 1);
for k = 1:2, idx = F.ch(k).idx;  chDist(idx) = lead + (0:numel(idx) - 1)' * step;  chId(idx) = k; end
% intruder
[~, iI] = min(abs(chDist - 0.4 * L) + 1e9 * (chId ~= 1));
Sc.intr = struct('idx', iI, 'lat', F.lat(iI), 'lon', F.lon(iI), 'ch', 1, 'z_m', chDist(iI));
j = [mod(iI - 2, F.n) + 1, mod(iI, F.n) + 1];  t = [fx(j(2)) - fx(j(1)), fy(j(2)) - fy(j(1))];  t = t / norm(t);
nrm = [t(2), -t(1)];                                                     % one of the two normals
inP = inpolygon(fx(iI) + 30 * nrm(1), fy(iI) + 30 * nrm(2), fx, fy);
if inP, nrm = -nrm; end                                                  % make nrm point OUTWARD
Sc.intr.tangent = t;  Sc.intr.outward = nrm;
% vehicle on an access road
R = load(fullfile(c.dataDir, 'roads_osm.mat')).roads;  ok = ismember([R.class], ["service" "secondary" "primary" "tertiary" "unclassified"]);
best = Inf;  Sc.veh = struct();
for r = find(ok)
    rx = (R(r).lon - lon0) * kx;  ry = (R(r).lat - lat0) * ky;  s = [0; cumsum(hypot(diff(rx), diff(ry)))];
    if s(end) < 10, continue; end
    q = (0:5:s(end))';  qx = interp1(s, rx, q);  qy = interp1(s, ry, q);
    for a = 1:numel(q)
        [dm, ik] = min(hypot(fx - qx(a), fy - qy(a)));
        if dm < 20 || dm > 100 || inpolygon(qx(a), qy(a), fx, fy), continue; end
        if min(abs(chDist(ik) - [0.2 0.4 0.6] * L)) < 800, continue; end   % keep the engine events apart
        sc = abs(chDist(ik) - 0.8 * L);
        if sc < best, best = sc; Sc.veh = struct('lat', lat0 + qy(a) / ky, 'lon', lon0 + qx(a) / kx, 'idx', ik, 'z_m', chDist(ik), 'ch', chId(ik), 'road', string(R(r).class), 'road_k', r, 'd_fence_m', dm); end
    end
end
assert(isfield(Sc.veh, 'idx') && ~isempty(Sc.veh.idx), 'no access road within 100 m of the fence');
Sc.events_z = struct('walk', Sc.intr.z_m, 'vehicle', Sc.veh.z_m);
fprintf('Intruder: channel %d at %.0f m (fence idx %d); vehicle: %s road %d, %.0f m from fence, channel %d at %.0f m\n', 1, Sc.intr.z_m, iI, Sc.veh.road, Sc.veh.road_k, Sc.veh.d_fence_m, Sc.veh.ch, Sc.veh.z_m);
save(fullfile(c.resDir, 'scenario.mat'), 'Sc');
end
