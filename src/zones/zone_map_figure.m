function zone_map_figure(c, tcfg, Z, G, ring, sub_xy)
% ZONE_MAP_FIGURE  results_zones/zone_cells_map.png: cells coloured by zone on the Esri plant-detail texture. No in-figure title.
M = load(tcfg.texMeta);  d = M.meta.mashaer;  img = imread(tcfg.texMashaer);
kx = G.kx / 1e3;  ky = G.ky / 1e3;
xl = (d.lon - G.lon0) * kx;  yl = (d.lat - G.lat0) * ky;
col = [0.20 0.45 0.80; 0.98 0.80 0.15; 0.85 0.12 0.12];          % Cold / Neutral / Hot
f = figure('Color', 'w', 'Position', [60 40 900 760], 'Visible', 'off');  ax = axes(f);  hold(ax, 'on');
image(ax, xl, yl, flipud(img));  set(ax, 'YDir', 'normal');
h = Z.cs / 2000;
for i = 1:Z.nSquares
    cx = Z.sqx_m(i) / 1e3;  cy = Z.sqy_m(i) / 1e3;  z = Z.zone(Z.sqCell(i));
    patch(ax, cx + h * [-1 1 1 -1], cy + h * [-1 -1 1 1], col(z, :), 'FaceAlpha', 0.35, 'EdgeColor', col(z, :), 'LineWidth', 0.4);
end
px = (Z.piece.x) / 1e3;  py = (Z.piece.y) / 1e3;
for z = 1:3
    k = Z.zone(Z.piece.cell) == z;  q = nan(size(px));  q(k) = px(k);  r = nan(size(py));  r(k) = py(k);
    plot(ax, q, r, '.', 'Color', col(z, :), 'MarkerSize', 3);
end
fill(ax, sub_xy(:,1) / 1e3, sub_xy(:,2) / 1e3, [1 1 1], 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 1);
axis(ax, 'equal');  xlim(ax, xl);  ylim(ax, yl);  box(ax, 'on');
xlabel(ax, 'East of plant centre (km)');  ylabel(ax, 'North of plant centre (km)');
hh = gobjects(1, 4);
for z = 1:3, hh(z) = patch(ax, NaN, NaN, col(z, :), 'FaceAlpha', 0.6, 'EdgeColor', col(z, :)); end
hh(4) = patch(ax, NaN, NaN, [1 1 1], 'EdgeColor', 'k');
legend(ax, hh([3 2 1 4]), {sprintf('Hot: %.1f km (within %g m of 380 kV substation)', Z.kmZone(3), Z.R_hot_sub), sprintf('Neutral: %.1f km', Z.kmZone(2)), sprintf('Cold: %.1f km', Z.kmZone(1)), '380 kV substation'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 8);
annotation(f, 'textbox', [0.02 0.005 0.96 0.03], 'String', [tcfg.imageryCredit ' Cells ' num2str(Z.cs) ' m.'], 'EdgeColor', 'none', 'FontSize', 6, 'Color', [0.35 0.4 0.45]);
exportgraphics(f, fullfile(c.zonesDir, 'zone_cells_map.png'), 'Resolution', 200);
exportgraphics(f, fullfile(c.zonesDir, 'zone_cells_map.pdf'), 'ContentType', 'image', 'Resolution', 200);  close(f);
end
