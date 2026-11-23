function draw_events_sudair(ax, scene, lw)
% DRAW_EVENTS_SUDAIR  ADAPTED COPY of DAS-map draw_events.m (a25fd0c): the UAV and patrol response blocks are removed (no drones, no patrols
% at Sudair) and the heat patch / ripple radii are scaled from Makkah km to plant km (x0.2). Rest unchanged.
% DRAW_EVENTS  Snapshot of the illustrative scenario: active breach zone, intruder track, alarm ripples,
% and a non-human event (vehicle: detected, classified non-human, logged).
hs_ = 1;  if isfield(scene, 'heatScale'), hs_ = scene.heatScale; end
cfg = scene.cfg;  c = cfg.col;  E = scene.events;  T = scene.T;  

% active breach zone: radial red heat patch draped on the terrain
[bx, by] = meshgrid(linspace(-0.30, 0.30, 56));   r = hypot(bx, by);
X = E.cross(1) + bx;   Y = E.cross(2) + by;   Zz = T.heightXY(X, Y) + 0.008;
CD = cat(3, ones(size(r)) * c.red(1), ones(size(r)) * c.red(2), ones(size(r)) * c.red(3));
surface(ax, X, Y, Zz, CD, 'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceAlpha', 'interp', ...
    'AlphaData', hs_ * 0.55 * max(1 - r / 0.30, 0).^1.4, 'AlphaDataMapping', 'none');

plot3(ax, E.trackX, E.trackY, E.trackZ, '-', 'Color', [c.red 0.28], 'LineWidth', 6 * lw);
plot3(ax, E.trackX, E.trackY, E.trackZ, ':', 'Color', [1 0.50 0.45 0.98], 'LineWidth', 2.2 * lw);
for rr = [0.15 0.30]                                       % alarm ripples
    a = linspace(0, 2*pi, 80)';   rx = E.cross(1) + rr * cos(a);   ry = E.cross(2) + rr * sin(a);
    plot3(ax, rx, ry, T.heightXY(rx, ry) + 0.010, '-', 'Color', [c.red 0.95 - 0.28 * rr], 'LineWidth', 1.6 * lw);
end
scatter3(ax, E.intruder(1), E.intruder(2), E.intruder(3) + 0.012, 150, 'o', 'MarkerFaceColor', c.red, ...
    'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor', 'none');
scatter3(ax, E.intruder(1), E.intruder(2), E.intruder(3) + 0.012, 32, 'o', 'MarkerFaceColor', c.red, ...
    'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.9);

for k = 1:numel(E.roadLines)                                   % the road the vehicle is on (OSM), highlighted
    r = E.roadLines{k};
    plot3(ax, r(:,1), r(:,2), r(:,3), '-', 'Color', [c.yellow 0.95], 'LineWidth', 2.0 * lw);
end
scatter3(ax, E.vehicle(1), E.vehicle(2), E.vehicle(3) + 0.012, 110, 'o', 'MarkerFaceColor', c.yellow, ...
    'MarkerFaceAlpha', 0.22, 'MarkerEdgeColor', 'none');
scatter3(ax, E.vehicle(1), E.vehicle(2), E.vehicle(3) + 0.012, 20, 'o', 'MarkerFaceColor', c.yellow, ...
    'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.7);
end
