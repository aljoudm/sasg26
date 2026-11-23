function draw_allocation_map(ax, cells, P, alloc, layout, stationXY, nDrones, ttl, subtitleNote)
% DRAW_ALLOCATION_MAP  Allocation map in the style of DAS-map (zone_cells_map): square cells coloured by zone, the boundary, the DAS fibre
% on the boundary, interrogators, drone stations with their response-radius circles, and every Hot cell marked verified / not verified.
%   alloc     struct with fibre_runs (logical per run) and interrogators (lat, lon)   [use the optimal solution or a baseline]
%   layout    from drone_layout (uses layout.verified)
S = load(fullfile(fileparts(mfilename('fullpath')), '..', 'inputs', 'dasmap', 'zones.mat'), 'Z');   Z = S.Z;
ring = cells.ring;   runs = cells.runs;
col = [0.27 0.46 0.71; 0.99 0.85 0.45; 0.84 0.19 0.15];                    % Cold / Neutral / Hot (DAS-map colours)
hold(ax, 'on');   h = Z.cs / 2000;
for k = 1:Z.nSquares
    cx = Z.sqx_m(k) / 1e3;   cy = Z.sqy_m(k) / 1e3;   c = Z.sqCell(k);
    patch(ax, cx + h * [-1 1 1 -1], cy + h * [-1 -1 1 1], col(cells.zoneCode(c), :), 'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 0.3);
end
plot(ax, [ring.x; ring.x(1)] / 1e3, [ring.y; ring.y(1)] / 1e3, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.6);
% DAS fibre: the runs that carry fibre, drawn as thick green lines on the boundary
xs = [];   ys = [];
for r = find(alloc.fibre_runs)'
    idx = find(ring.s >= runs.s0(r) & ring.s <= runs.s1(r));
    xs = [xs; ring.x(idx) / 1e3; NaN];   ys = [ys; ring.y(idx) / 1e3; NaN]; %#ok<AGROW>
end
hF = plot(ax, xs, ys, '-', 'Color', [0.02 0.42 0.18], 'LineWidth', 2.4);
% drone stations and response circles
th = linspace(0, 2 * pi, 200);   hC = [];
for s = 1:size(stationXY, 1)
    hC = plot(ax, (stationXY(s, 1) + P.v.R_resp_m * cos(th)) / 1e3, (stationXY(s, 2) + P.v.R_resp_m * sin(th)) / 1e3, '--', 'Color', [0.35 0.1 0.6], 'LineWidth', 1.0);
end
% interrogators
ix = (alloc.interrogators.lon - ring.lon0) * ring.kx / 1e3;   iy = (alloc.interrogators.lat - ring.lat0) * ring.ky / 1e3;
hI = plot(ax, ix, iy, 's', 'MarkerSize', 11, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'LineWidth', 1.2);
% Hot cells: verified (white disc, green rim) / not verified (black cross)
hot = find(cells.zoneCode == 3);   cxy = layout.centre_xy / 1e3;   ver = layout.verified(hot);
hV = plot(ax, cxy(hot(ver), 1), cxy(hot(ver), 2), 'o', 'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', [0.02 0.42 0.18], 'LineWidth', 1.8);
hU = plot(ax, cxy(hot(~ver), 1), cxy(hot(~ver), 2), 'kx', 'MarkerSize', 9, 'LineWidth', 2.0);
% drone stations are drawn LAST (on top of every other layer), larger, with the number of drones written beside each station
hD = plot(ax, stationXY(:, 1) / 1e3, stationXY(:, 2) / 1e3, '^', 'MarkerSize', 17, 'MarkerFaceColor', [0.55 0.25 0.85], 'MarkerEdgeColor', 'w', 'LineWidth', 2.0);
for s = 1:size(stationXY, 1)
    lab = sprintf('%d drones', nDrones(s));   if nDrones(s) == 1, lab = '1 drone'; end
    text(ax, stationXY(s, 1) / 1e3 + 0.7, stationXY(s, 2) / 1e3 + 0.7, lab, 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.35 0.1 0.6], ...
        'BackgroundColor', 'w', 'EdgeColor', [0.35 0.1 0.6], 'Margin', 2, 'Clipping', 'off');
end
uistack(hD, 'top');
axis(ax, 'equal');   box(ax, 'on');   grid(ax, 'on');   ax.Layer = 'top';
xlabel(ax, 'East from boundary centre (km)');   ylabel(ax, 'North from boundary centre (km)');
hz = [patch(ax, NaN, NaN, col(3, :)), patch(ax, NaN, NaN, col(2, :)), patch(ax, NaN, NaN, col(1, :))];
items = [hz, hF, hI, hD, hC, hV, hU];
names = {'Hot', 'Neutral', 'Cold', 'DAS fibre on the boundary', 'Interrogator', 'Drone station (number of drones)', sprintf('Response radius R_{resp} = %.2f km', P.v.R_resp_m / 1e3), ...
    sprintf('Hot cell with verification layer (%d)', nnz(ver)), sprintf('Hot cell WITHOUT verification layer (%d)', nnz(~ver))};
ok = arrayfun(@(x) ~isempty(x) && isgraphics(x), items);
legend(ax, items(ok), names(ok), 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', 8);
title(ax, ttl, 'FontSize', 9);   if nargin >= 9 && ~isempty(subtitleNote), subtitle(ax, subtitleNote, 'FontSize', 8, 'Color', [0.5 0 0], 'Interpreter', 'none'); end
end
