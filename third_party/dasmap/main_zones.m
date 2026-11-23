% MAIN_ZONES  Zone classification of the boundary cells (Hot / Neutral / Cold) and the Sheet values that come out of it:
% cell_size, R_hot, R_cold, per-cell lambda, number of cells per zone. All decisions are parameters in map_params.m.
% Outputs (results_zones/): cells.csv, zone_cells_map.(png|pdf), risk_histogram.(png|pdf), sensitivity.csv, zones.mat.
here = fileparts(mfilename('fullpath'));
addpath(here);
cfg = config();   m = cfg.m;
outDir = fullfile(here, 'results_zones');   if ~exist(outDir, 'dir'), mkdir(outDir); end
ring = readmatrix(m.L_boundary_source);   if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end
lat0 = mean([min(ring(:,1)) max(ring(:,1))]);   lon0 = mean([min(ring(:,2)) max(ring(:,2))]);
fprintf('Intrinsic risk grid (terrain + roads, no CCTV term; weights slope/road = %.3f/%.3f) ...\n', m.zone_w);
G = intrinsic_risk_grid(cfg, lat0, lon0);
if all(m.lambda_cold_range == 0)
    warning('ZONES:lambdaCold', 'Cold cells will never get simulated intrusions: performance in Cold zones cannot be evaluated.');
end

%% main run and sensitivity
sizes = unique([m.cell_size, m.cell_size_sens]);   S = cell(numel(sizes), 1);
for i = 1:numel(sizes), S{i} = zone_classify(m, ring, G, sizes(i)); end
Z = S{sizes == m.cell_size};
zn = {'Cold', 'Neutral', 'Hot'};

fprintf('\nZones, cell_size = %g m [P%d of intrinsic risk in the cell, k-means k = %d]\n', Z.cs, m.cell_risk_pct, m.zone_k);
fprintf('  k-means centres : %s\n', mat2str(Z.centres', 4));
fprintf('  R_cold = %.4f   R_hot = %.4f   (Cold < R_cold <= Neutral < R_hot <= Hot; risk is a proxy, no intrusion history)\n', Z.R_cold, Z.R_hot);
fprintf('  squares crossed by the boundary %d (%d with boundary < %g%% of cell_size) -> %d merged into the neighbour along the boundary\n', Z.nSquares, Z.nSmall0, 100 * m.min_cell_frac, Z.nMerged);
fprintf('  cells total %d : Hot %d / Neutral %d / Cold %d\n', Z.nCells, Z.nZone(3), Z.nZone(2), Z.nZone(1));
fprintf('  boundary km    : Hot %.1f / Neutral %.1f / Cold %.1f  (sum %.1f km; map_params L_boundary %.1f km)\n', Z.kmZone(3), Z.kmZone(2), Z.kmZone(1), Z.L_total_km, m.L_boundary / 1e3);
for z = [3 2 1], fprintf('  lambda %-8s : %g-%g events/day per zone (mid %g); per cell mean %.3f / max %.3f (mid); sum over cells min/mid/max = %s\n', zn{z}, Z.lambdaZone(z,1), Z.lambdaZone(z,2), mean(Z.lambdaZone(z,:)), ...
    mean(Z.lambda(Z.zone == z, 2), 'omitnan'), max([Z.lambda(Z.zone == z, 2); 0]), mat2str(Z.lambdaSum{z}, 6)); end
fprintf('\nSensitivity (cell_size):\n  %8s %8s %6s %6s %6s %6s %9s %9s\n', 'cell [m]', 'cells', 'Hot', 'Neutr', 'Cold', 'merged', 'R_hot', 'R_cold');
sens = zeros(numel(sizes), 10);
for i = 1:numel(sizes)
    q = S{i};   sens(i, :) = [q.cs q.nCells q.nZone(3) q.nZone(2) q.nZone(1) q.R_hot q.R_cold sum(q.Lc_m(q.zone == 3)) / 1e3 q.nSquares q.nMerged];
    fprintf('  %8g %8d %6d %6d %6d %6s %9.4f %9.4f\n', q.cs, q.nCells, q.nZone(3), q.nZone(2), q.nZone(1), sprintf('%d', q.nMerged), q.R_hot, q.R_cold);
end
writetable(array2table(sens, 'VariableNames', {'cell_size_m','cells','hot','neutral','cold','R_hot','R_cold','hot_boundary_km','squares_before_merge','merged'}), fullfile(outDir, 'sensitivity.csv'));

%% cells.csv
T = table(Z.id, Z.lat, Z.lon, Z.nsq, Z.Lc_m, Z.risk, string(zn(Z.zone))', Z.lambda(:,1), Z.lambda(:,2), Z.lambda(:,3), Z.cameras, ...
    'VariableNames', {'cell_id','centre_lat','centre_lon','n_squares_merged','boundary_length_m','cell_risk_P90','zone','lambda_cell_min','lambda_cell_mid','lambda_cell_max','approx_cameras_needed'});
writetable(T, fullfile(outDir, 'cells.csv'), 'Encoding', 'UTF-8');
save(fullfile(outDir, 'zones.mat'), 'Z', 'S', 'sizes', 'sens');
fprintf('\nSaved %s\n', fullfile(outDir, 'cells.csv'));

%% figures
col = [0.27 0.46 0.71; 0.99 0.85 0.45; 0.84 0.19 0.15];          % Cold / Neutral / Hot (blue / yellow / red)
kx = G.kx / 1e3;   ky = G.ky / 1e3;                                % km per degree
f1 = figure('Color', 'w', 'Position', [60 40 960 700], 'Visible', 'off');   ax = axes(f1);   hold(ax, 'on');
h = Z.cs / 2000;                                                   % half cell [km]
for i = 1:Z.nSquares
    cx = Z.sqx_m(i) / 1e3;   cy = Z.sqy_m(i) / 1e3;   c = Z.sqCell(i);   mg = Z.nsq(c) > 1;       % squares of merged cells get a heavier outline
    patch(ax, cx + h * [-1 1 1 -1], cy + h * [-1 -1 1 1], col(Z.zone(c), :), 'EdgeColor', mg * [0 0 0] + ~mg * [0.35 0.35 0.35], 'LineWidth', 0.3 + 1.0 * mg);
end
plot(ax, (ring(:,2) - G.lon0) * kx, (ring(:,1) - G.lat0) * ky, 'k-', 'LineWidth', 0.8);
axis(ax, 'equal');   box(ax, 'on');   grid(ax, 'on');   ax.Layer = 'top';
xlabel(ax, 'East from boundary centre (km)');   ylabel(ax, 'North from boundary centre (km)');
colormap(ax, col);   clim(ax, [0.5 3.5]);   cb = colorbar(ax, 'Ticks', 1:3, 'TickLabels', zn);   cb.Label.String = 'Zone (k-means thresholds on cell risk)';
hb = plot(ax, NaN, NaN, 'k-', 'LineWidth', 0.8);   hm = patch(ax, NaN, NaN, [1 1 1], 'EdgeColor', 'k', 'LineWidth', 1.3);
legend(ax, [hb hm], {sprintf('Boundary (%.1f km); cells of %g m crossed by it', Z.L_total_km, Z.cs), sprintf('Merged cell (boundary < %g%% of cell size; %d merged)', 100 * m.min_cell_frac, Z.nMerged)}, 'Location', 'southoutside');
exportgraphics(f1, fullfile(outDir, 'zone_cells_map.png'), 'Resolution', 300);
exportgraphics(f1, fullfile(outDir, 'zone_cells_map.pdf'), 'ContentType', 'vector');   close(f1);

f2 = figure('Color', 'w', 'Position', [60 40 900 560], 'Visible', 'off');   ax = axes(f2);   hold(ax, 'on');
edges = linspace(min(Z.risk), max(Z.risk), 26);
for z = 1:3, histogram(ax, Z.risk(Z.zone == z), edges, 'FaceColor', col(z, :), 'EdgeColor', [0.3 0.3 0.3], 'FaceAlpha', 1); end
yl = [0 max(histcounts(Z.risk, edges)) * 1.12];   ylim(ax, yl);
l1 = plot(ax, Z.R_cold * [1 1], yl, 'k--', 'LineWidth', 1.4);   l2 = plot(ax, Z.R_hot * [1 1], yl, 'k-', 'LineWidth', 1.4);
xlabel(ax, 'Cell risk (P90 of intrinsic risk, 0-1)');   ylabel(ax, 'Number of cells');   box(ax, 'on');   grid(ax, 'on');
legend(ax, [findobj(ax, 'Type', 'histogram')', l1, l2], [fliplr(zn), {sprintf('R_{cold} = %.3f', Z.R_cold), sprintf('R_{hot} = %.3f', Z.R_hot)}], ...
    'Location', 'southoutside', 'Orientation', 'horizontal');
exportgraphics(f2, fullfile(outDir, 'risk_histogram.png'), 'Resolution', 300);
exportgraphics(f2, fullfile(outDir, 'risk_histogram.pdf'), 'ContentType', 'vector');   close(f2);
fprintf('Saved figures in %s\n', outDir);

% Sheet export with the zone rows filled
export_sheet_values(m, fullfile(here, 'results_febus'), Z);
