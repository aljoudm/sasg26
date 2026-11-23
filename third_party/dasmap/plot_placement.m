function png = plot_placement(cfg, F)
% PLOT_PLACEMENT  Plan view of the interrogator sites and fibre segments (2D, labelled axes in km).
% Fibre colour = fibre distance from the interrogator along its channel (0 .. segment length); channels 1-2 only.
th = get_theme(cfg, 'light');  P = cfg.m;
lat0 = mean(F.lat);  R = 6371.0088;
x = deg2rad(F.lon - mean(F.lon)) * R * cosd(lat0);  y = deg2rad(F.lat - lat0) * R;
n = numel(x);
fig = figure('Color', 'w', 'Position', [60 40 960 640], 'Visible', 'off');
ax = axes(fig);  hold(ax, 'on');
plot(ax, x, y, '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 4);
dist = nan(n, 1);  segId = zeros(n, 1);
for q = 1:F.nSeg
    i0 = F.segNearIdx(q);  len = F.segLenKm(q);  dd = (0:cfg.DENSIFY_STEP_M / 1e3:len)';
    idx = 1 + mod(i0 - 1 + F.segDir(q) * round(dd * 1e3 / cfg.DENSIFY_STEP_M), n - 1);
    dist(idx) = dd;  segId(idx) = q;
end
xs = x;  ys = y;  xs(isnan(dist)) = NaN;  ys(isnan(dist)) = NaN;
patch(ax, 'XData', [xs; NaN], 'YData', [ys; NaN], 'CData', [dist; NaN], 'FaceColor', 'none', 'EdgeColor', 'interp', 'LineWidth', 3);
colormap(ax, parula);  cb = colorbar(ax);  cb.Label.String = 'Fibre distance along channel from segment start (km)';
clim(ax, [0 max(F.segLenKm)]);
hE = plot(ax, x(unique([F.segNearIdx; F.segFarIdx])), y(unique([F.segNearIdx; F.segFarIdx])), 'd', 'MarkerSize', 7, ...
    'MarkerFaceColor', [1 0.8 0], 'MarkerEdgeColor', 'k');
hS = plot(ax, x(F.iuIdx), y(F.iuIdx), 's', 'MarkerSize', 11, 'MarkerFaceColor', [0.05 0.25 0.6], 'MarkerEdgeColor', 'w', 'LineWidth', 1.2);
for k = 1:numel(F.iuIdx), text(ax, x(F.iuIdx(k)), y(F.iuIdx(k)), sprintf('  IU-%d', k), 'FontWeight', 'bold', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right'); end
hF = plot(ax, NaN, NaN, 's', 'MarkerSize', 7, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.05 0.25 0.6]);
axis(ax, 'equal');  xlabel(ax, 'East from boundary centre (km)');  ylabel(ax, 'North from boundary centre (km)');
box(ax, 'on');  grid(ax, 'on');
legend(ax, [hS hE hF], {'Interrogator site', 'Segment end', 'Ch. 3-4 per site: spare (redundancy / possible double coverage in Hot zones), no segment'}, 'Location', 'southoutside', 'Orientation', 'vertical');
png = fullfile(cfg.outDir, 'placement_plan.png');
exportgraphics(fig, png, 'Resolution', 300);
exportgraphics(fig, strrep(png, '.png', '.pdf'), 'ContentType', 'vector');
close(fig);
fprintf('Saved %s (+ .pdf)\n', png);
end
