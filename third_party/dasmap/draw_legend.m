function draw_legend(fig, pos, scene, ncols, framed)
% DRAW_LEGEND  Legend of every symbol on the map. ncols = 6 gives the two-row strip of the static figure; the interactive
% window uses fewer columns inside a framed panel.
if nargin < 4, ncols = 7; end
if nargin < 5, framed = false; end
cfg = scene.cfg;  th = scene.th;  c = cfg.col;  fn = cfg.font;  ks = cfg.uiScale;
if framed
    ax = panel_axes(fig, pos, th, ks);
else
    ax = axes(fig, 'Position', pos, 'Color', 'none');   hold(ax, 'on');
    ax.XLim = [0 1];   ax.YLim = [0 1];   axis(ax, 'off');   ax.Tag = 'panel';
end
edge = th.text;
names = {'DAS fibre', 'Light pulse', 'Sim. section', 'Interrogator', 'C2 centre', 'Road entry', ...
         'CCTV + FOV', 'UAV + cone', 'Patrol', 'Intruder', 'Vehicle on road', 'Weak coverage', 'Segment end', 'Ch. 3-4: spare'};
nrows = ceil(14 / ncols);
wdes = pos(3) * cfg.figSizeIn(1) / ks;   hdes = pos(4) * cfg.figSizeIn(2) / ks;      % panel size in design inches
kx = (0.775 * 8) / wdes;                                          % keeps icon widths equal to the static legend's (absolute)
vs = 0.41 / hdes;                                                 % ... and glyph heights
for k = 1:14
    col = mod(k - 1, ncols);   row = floor((k - 1) / ncols);
    x = col / ncols + 0.008;   y = 1 - (row + 0.5) / nrows;   xi = x + 0.014 * kx;
    k6 = kx;
    switch k
        case 1
            seg = [c.cyan; c.green; c.yellow; c.red];
            for q = 1:4, plot(ax, x + k6 * ([0 0.0065] + (q - 1) * 0.0062), [y y], '-', 'Color', seg(q, :), 'LineWidth', 1.6 * ks); end
        case 2
            plot(ax, x + k6 * [0 0.026], [y y], '-', 'Color', [c.cyan 0.55], 'LineWidth', 3.4 * ks);
            plot(ax, x + k6 * [0 0.026], [y y], '-', 'Color', [1 1 1], 'LineWidth', 1.2 * ks);
        case 3
            plot(ax, x + k6 * [0 0.026], [y + 0.14 * vs y + 0.14 * vs], '--', 'Color', edge, 'LineWidth', 0.8 * ks);
            plot(ax, x + k6 * [0 0.026], [y - 0.14 * vs y - 0.14 * vs], '--', 'Color', edge, 'LineWidth', 0.8 * ks);
        case 4, plot(ax, xi, y, 's', 'MarkerSize', 4.2 * ks, 'MarkerFaceColor', c.iu, 'MarkerEdgeColor', th.frame, 'LineWidth', 0.8 * ks);
        case 5, plot(ax, xi, y, 'p', 'MarkerSize', 6.5 * ks, 'MarkerFaceColor', c.c2, 'MarkerEdgeColor', edge, 'LineWidth', 0.4 * ks);
        case 6, plot(ax, xi, y, 'd', 'MarkerSize', 4.6 * ks, 'MarkerFaceColor', c.entry, 'MarkerEdgeColor', edge, 'LineWidth', 0.6 * ks);
        case 7
            hw = 0.012 * k6;   hh = 0.15 * vs;
            patch(ax, [xi xi + hw xi + hw], [y y + hh y - hh], c.cctv, 'FaceAlpha', 0.5, 'EdgeColor', c.cctv, 'LineWidth', 0.4 * ks);
            plot(ax, xi, y, 'o', 'MarkerSize', 3 * ks, 'MarkerFaceColor', c.cctv, 'MarkerEdgeColor', edge, 'LineWidth', 0.4 * ks);
        case 8
            hw = 0.010 * k6;   hh = 0.16 * vs;
            patch(ax, [xi xi + hw xi - hw], [y + 0.75 * hh y - 1.25 * hh y - 1.25 * hh], c.cyan, 'FaceAlpha', 0.35, 'EdgeColor', c.cyan, 'LineWidth', 0.4 * ks);
            plot(ax, xi, y + 0.75 * hh, 'o', 'MarkerSize', 3.4 * ks, 'MarkerFaceColor', c.uav, 'MarkerEdgeColor', th.frame, 'LineWidth', 0.6 * ks);
        case 9,  plot(ax, xi, y, 's', 'MarkerSize', 4 * ks, 'MarkerFaceColor', c.patrol, 'MarkerEdgeColor', edge, 'LineWidth', 0.5 * ks);
        case 10, plot(ax, xi, y, 'o', 'MarkerSize', 4.6 * ks, 'MarkerFaceColor', c.red, 'MarkerEdgeColor', edge, 'LineWidth', 0.4 * ks);
        case 11, plot(ax, xi, y, 'o', 'MarkerSize', 4.2 * ks, 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', edge, 'LineWidth', 0.4 * ks);
        case 12
            hh = 0.16 * vs;
            patch(ax, [x x + 0.0095 * k6 x + 0.0095 * k6 x], [y - hh y - hh y + hh y + hh], c.riskLo, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
            patch(ax, [x + 0.0095 * k6 x + 0.019 * k6 x + 0.019 * k6 x + 0.0095 * k6], [y - hh y - hh y + hh y + hh], c.riskHi, 'EdgeColor', 'none', 'FaceAlpha', 0.85);
        case 13, plot(ax, xi, y, 'd', 'MarkerSize', 3.6 * ks, 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', th.frame, 'LineWidth', 0.5 * ks);
        case 14, plot(ax, xi, y, 's', 'MarkerSize', 4.2 * ks, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', edge, 'LineWidth', 0.8 * ks);   % IU channels 3-4: redundancy / possible double coverage in Hot zones
    end
    text(ax, x + 0.034 * k6 + 0.004, y, names{k}, 'Color', th.text, 'FontName', fn.name, 'FontSize', fn.panel.size - 0.6 * ks, ...
        'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
end
end
