function F = place_fibre_sudair(save_out)
% PLACE_FIBRE_SUDAIR  Stage D. Adapted from DAS-map compute_fibre.m (same rule: densify the boundary, two active channels per
% interrogator, one in each direction, channel fibre = lead-in + sensing length <= R_DAS, assert kept). Differences for a known site:
%   * the interrogator sits INSIDE the plant control room / substation building (T_op 5-40 degC), represented by the centroid of the
%     380 kV substation polygon [ASSUMED: control room in the substation compound; no separate control-room location found in OSM];
%   * the lead-in (building -> fence entry point, straight run [ASSUMED: no slack]) is COUNTED in each channel's fibre.
% With a single building every channel must start at the fence entry point, so only N = 1 is geometrically valid: the two channels
% run one each way around the ring. If the assert fails, a second shelter would be needed (error, not silent).
if nargin < 1, save_out = true; end
c = sasg_config();
R_DAS_km = 20;  N_active = 2;  N_ch = 4;  step_m = 20;  dz_samp = 2;     % [DATASHEET] [DERIVED] [DATASHEET] [ASSUMED: DAS-map] [SIM SETTING]
ring = readmatrix(c.boundaryCsv);  if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end
S = load(fullfile(c.dataDir, 'substations.mat')).S;  sub = S([S.id] == c.subWayId);
bld = mean(sub.g(1:end-1,:), 1);                                         % [lat lon] building = substation centroid
Rm = 6371008.8;
seg = hav(ring(1:end-1,:), ring(2:end,:), Rm);  s0 = [0; cumsum(seg)];  Lgeo = s0(end);
n = max(ceil(Lgeo / step_m), 2);  s = linspace(0, Lgeo, n + 1)';
[s0u, iu] = unique(s0);  lat = interp1(s0u, ring(iu,1), s);  lon = interp1(s0u, ring(iu,2), s);   % closed, last = first
lat = lat(1:end-1);  lon = lon(1:end-1);  s = s(1:end-1);  n = numel(lat);
ky = 111195;  kx = ky * cosd(mean(lat));
d = hypot((lat - bld(1)) * ky, (lon - bld(2)) * kx);   [lead_m, e] = min(d);   % entry point = fence point nearest to the building
L_km = Lgeo / 1e3;
sense_km = L_km / N_active;                                              % N = 1: each channel senses half the ring
need = lead_m / 1e3 + sense_km;
assert(need <= R_DAS_km + 1e-9, 'A sensing channel exceeds R_DAS (%.2f km > %g km): a second shelter is needed.', need, R_DAS_km);
h = round(n / 2);
F.lat = lat;  F.lon = lon;  F.s_m = s;  F.n = n;  F.entryIdx = e;  F.entryLat = lat(e);  F.entryLon = lon(e);
F.building = bld;  F.lead_m = lead_m;
F.ch(1) = struct('dir', +1, 'idx', mod(e - 1 + (0:h), n) + 1);          % channel 1: forward, first half
F.ch(2) = struct('dir', -1, 'idx', mod(e - 1 - (0:(n - h)), n) + 1);    % channel 2: backward, rest
F.chLenKm = [(numel(F.ch(1).idx) - 1) (numel(F.ch(2).idx) - 1)] * (L_km / n);
F.chNeedKm = lead_m / 1e3 + F.chLenKm;                                   % total fibre per channel, lead-in counted
F.marginKm = R_DAS_km - F.chNeedKm;
F.N_IU = 1;  F.N_ch = N_ch;  F.N_ch_active = N_active;  F.N_ch_spare = N_ch - N_active;  F.R_DAS_km = R_DAS_km;
F.L_km = L_km;  F.fibreTotalKm = L_km + 2 * lead_m / 1e3;
F.N_sensing = round(L_km * 1e3 / dz_samp);                               % sensing points = fibre / 2 m
F.dz_samp = dz_samp;  F.longestChannelKm = max(F.chNeedKm);
fprintf('Interrogators %d (building at %.5f, %.5f); lead-in %.0f m counted per channel\n', F.N_IU, bld(1), bld(2), lead_m);
fprintf('Channel fibre (lead-in + sensing) [km]: %.3f, %.3f (R_DAS %g km, margin %.3f / %.3f); spare channels %d\n', F.chNeedKm, R_DAS_km, F.marginKm, F.N_ch_spare);
fprintf('Boundary fibre %.3f km, total incl. lead-ins %.3f km, sensing points %d (fibre/%g m)\n', L_km, F.fibreTotalKm, F.N_sensing, dz_samp);
if save_out
    if ~exist(c.resDir, 'dir'), mkdir(c.resDir); end
    save(fullfile(c.resDir, 'placement.mat'), 'F');
    writetable(table((1:2)', F.chLenKm', repmat(lead_m / 1e3, 2, 1), F.chNeedKm', F.marginKm', 'VariableNames', {'channel','sensing_km','leadin_km','fibre_km','margin_to_R_DAS_km'}), fullfile(c.resDir, 'placement_channels.csv'));
end
end
function d = hav(a, b, R)
dlat = deg2rad(b(:,1) - a(:,1));  dlon = deg2rad(b(:,2) - a(:,2));
h = sin(dlat/2).^2 + cosd(a(:,1)) .* cosd(b(:,1)) .* sin(dlon/2).^2;
d = 2 * R * asin(min(1, sqrt(h)));
end
