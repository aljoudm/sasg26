function draw_assets_sudair(ax, scene, lw)
% DRAW_ASSETS_SUDAIR  ADAPTED COPY of DAS-map draw_assets.m (a25fd0c): UAV drawing removed (no drones at Sudair); interrogator pole height and
% ground ring scaled from Makkah km to plant km (1.4 -> 0.16, 0.55 -> 0.12) [display only]. Rest unchanged.
cfg = scene.cfg;  c = cfg.col;  th = scene.th;  F = scene.fibre;  T = scene.T;  ks = cfg.uiScale;

for k = 1:numel(F.iuIdx)                                   % IU: pole + square head + ground ring
    x = F.iuX(k);  y = F.iuY(k);  z0 = F.iuZ(k);  h = 0.16;
    plot3(ax, [x x], [y y], [z0 z0 + h], '-', 'Color', [c.cyan 0.7], 'LineWidth', 1.4 * lw);
    drawRing(ax, T, x, y, 0.12, [c.cyan 0.9], 1.4 * lw);
    scatter3(ax, x, y, z0 + h, 46 * ks^2, 's', 'MarkerFaceColor', c.iu, 'MarkerEdgeColor', th.frame, 'LineWidth', 0.9 * ks, 'Tag', 'iu');
end
scatter3(ax, F.segEndX, F.segEndY, F.segEndZ + 0.05, 14 * ks^2, 'd', 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', th.frame, ...
    'LineWidth', 0.5 * ks, 'Tag', 'segend');                  % fibre-segment ends (each channel serves one segment)
end

function drawRing(ax, T, x, y, r, col, lw)
a = linspace(0, 2*pi, 60)';   rx = x + r * cos(a);   ry = y + r * sin(a);
plot3(ax, rx, ry, T.heightXY(rx, ry) + 0.03, '-', 'Color', col, 'LineWidth', lw);
end
