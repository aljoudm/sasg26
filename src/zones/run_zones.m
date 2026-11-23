function R = run_zones(quick)
% RUN_ZONES  Stage C. Intrinsic risk grid (DAS-map intrinsic_risk_grid, unchanged: slope + road distance; no wadi term, see
% report/decisions.md), zones Hot/Neutral/Cold per 250 m cell, sensitivity (cell size 100/250/500 m x R_hot_sub half/1x/double).
% Outputs: results_zones/{cells.csv,zone_lengths.csv,sensitivity.csv,zones.mat,zone_cells_map.png|pdf}
if nargin < 1, quick = false; end
c = sasg_config();  m = zone_params();
tcfg = prepare_terrain_sudair();
ring = readmatrix(c.boundaryCsv);
lat0 = mean([min(ring(:,1)) max(ring(:,1))]);   lon0 = mean([min(ring(:,2)) max(ring(:,2))]);
% roads for the risk term = DAS-map classes (motorway..tertiary + links); all roads stay in data/roads_osm.mat for drawing
Rr = load(fullfile(c.dataDir, 'roads_osm.mat'));  keep = ismember([Rr.roads.class], m.road_classes);  roads = Rr.roads(keep); %#ok<NASGU>
rd = fullfile(c.dataDir, 'roads_major');  if ~exist(rd, 'dir'), mkdir(rd); end
save(fullfile(rd, 'roads_osm.mat'), 'roads');
fprintf('Risk roads: %d of %d ways (%s)\n', nnz(keep), numel(Rr.roads), strjoin(unique([roads.class]), ','));
gcfg.m = m;  gcfg.demMat = tcfg.demMat;  gcfg.dataDir = rd;
G = intrinsic_risk_grid(gcfg, lat0, lon0);
S = load(fullfile(c.dataDir, 'substations.mat')).S;  sub = S([S.id] == c.subWayId);
sub_xy = [(sub.g(:,2) - G.lon0) * G.kx, (sub.g(:,1) - G.lat0) * G.ky];
if quick, sizes = m.cell_size; Rs = m.R_hot_sub; else, sizes = m.cell_size_sens; Rs = m.R_hot_sub * [0.5 1 2]; end
sizes = unique([m.cell_size sizes]);  Rs = unique([m.R_hot_sub Rs]);
rows = [];  Zmain = [];
for cs = sizes
    for Rh = Rs
        Z = zone_classify_sudair(m, ring, G, cs, sub_xy, Rh);
        rows = [rows; cs Rh Z.nCells Z.nZone(3) Z.nZone(2) Z.nZone(1) Z.kmZone(3) Z.kmZone(2) Z.kmZone(1) Z.L_total_km Z.nMerged]; %#ok<AGROW>
        if cs == m.cell_size && Rh == m.R_hot_sub, Zmain = Z; end
    end
end
Z = Zmain;  zn = ["Cold" "Neutral" "Hot"];
fprintf('\nZones, cell %g m, R_hot_sub %g m: cells %d (Hot %d / Neutral %d / Cold %d)\n', Z.cs, Z.R_hot_sub, Z.nCells, Z.nZone(3), Z.nZone(2), Z.nZone(1));
fprintf('Per-zone fence length [km]: Hot %.3f / Neutral %.3f / Cold %.3f  (sum %.3f; L_boundary %.3f)\n', Z.kmZone(3), Z.kmZone(2), Z.kmZone(1), sum(Z.kmZone), Z.L_total_km);
fprintf('lambda per zone: TBD (PLACEHOLDER, no Sudair source); R_cold = %.4f\n', Z.R_cold);
if ~exist(c.zonesDir, 'dir'), mkdir(c.zonesDir); end
writetable(array2table(rows, 'VariableNames', {'cell_size_m','R_hot_sub_m','cells','hot','neutral','cold','hot_km','neutral_km','cold_km','L_total_km','merged'}), fullfile(c.zonesDir, 'sensitivity.csv'));
tbd = repmat("TBD", Z.nCells, 1);
T = table(Z.id, Z.lat, Z.lon, Z.nsq, Z.Lc_m, Z.risk, Z.dSub_m, zn(Z.zone)', tbd, tbd, tbd, ...
    'VariableNames', {'cell_id','centre_lat','centre_lon','n_squares_merged','boundary_length_m','cell_risk_P90','dist_to_substation_m','zone','lambda_cell_min','lambda_cell_mid','lambda_cell_max'});
writetable(T, fullfile(c.zonesDir, 'cells.csv'), 'Encoding', 'UTF-8');
writetable(table(zn(3:-1:1)', Z.nZone(3:-1:1)', Z.kmZone(3:-1:1)', 'VariableNames', {'zone','cells','length_km'}), fullfile(c.zonesDir, 'zone_lengths.csv'));
save(fullfile(c.zonesDir, 'zones.mat'), 'Z', 'rows', 'sub_xy', 'G', 'lat0', 'lon0');
R.Z = Z;  R.rows = rows;
if ~quick, zone_map_figure(c, tcfg, Z, G, ring, sub_xy); end
end
