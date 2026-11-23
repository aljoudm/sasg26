function draw_events(ax, scene, lw)
% DRAW_EVENTS  Snapshot of the illustrative scenario: active breach zone, intruder track, alarm ripples,
% UAV and patrol response (dashed), and a non-human event (vehicle: detected, classified non-human, logged).
cfg = scene.cfg;  c = cfg.col;  E = scene.events;  T = scene.T;  A = scene.assets;

% active breach zone: radial red heat patch draped on the terrain
[bx, by] = meshgrid(linspace(-2.8, 2.8, 56));   r = hypot(bx, by);
X = E.cross(1) + bx;   Y = E.cross(2) + by;   Zz = T.heightXY(X, Y) + 0.045;
CD = cat(3, ones(size(r)) * c.red(1), ones(size(r)) * c.red(2), ones(size(r)) * c.red(3));
surface(ax, X, Y, Zz, CD, 'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceAlpha', 'interp', ...
    'AlphaData', 0.55 * max(1 - r / 2.8, 0).^1.4, 'AlphaDataMapping', 'none');

plot3(ax, E.trackX, E.trackY, E.trackZ, '-', 'Color', [c.red 0.28], 'LineWidth', 6 * lw);
plot3(ax, E.trackX, E.trackY, E.trackZ, ':', 'Color', [1 0.50 0.45 0.98], 'LineWidth', 2.2 * lw);
for rr = [0.8 1.6 2.4]                                       % alarm ripples
    a = linspace(0, 2*pi, 80)';   rx = E.cross(1) + rr * cos(a);   ry = E.cross(2) + rr * sin(a);
    plot3(ax, rx, ry, T.heightXY(rx, ry) + 0.05, '-', 'Color', [c.red 0.95 - 0.28 * rr], 'LineWidth', 1.6 * lw);
end
scatter3(ax, E.intruder(1), E.intruder(2), E.intruder(3) + 0.06, 150, 'o', 'MarkerFaceColor', c.red, ...
    'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor', 'none');
scatter3(ax, E.intruder(1), E.intruder(2), E.intruder(3) + 0.06, 32, 'o', 'MarkerFaceColor', c.red, ...
    'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.9);

for k = 1:numel(scene.uav)                                    % nearest UAV: dashed response arc
    if ~scene.uav(k).responding, continue; end
    u = scene.uav(k);   t = linspace(0, 1, 50)';
    px = u.x + (E.cross(1) - u.x) * t;   py = u.y + (E.cross(2) - u.y) * t;
    pz = u.z + (E.intruder(3) + 0.3 - u.z) * t - 0.25 * sin(pi * t);
    plot3(ax, px, py, pz, '--', 'Color', [1 1 1 0.95], 'LineWidth', 1.8 * lw);
end
p = A.patrol(A.patrolNearest, :);                              % nearest patrol: dashed ground route
t = linspace(0, 1, 60)';
px = p(1) + (E.cross(1) - p(1)) * t;   py = p(2) + (E.cross(2) - p(2)) * t;
plot3(ax, px, py, T.heightXY(px, py) + 0.07, '--', 'Color', [c.patrol 0.98], 'LineWidth', 1.8 * lw);

for k = 1:numel(E.roadLines)                                   % the road the vehicle is on (OSM), highlighted
    r = E.roadLines{k};
    plot3(ax, r(:,1), r(:,2), r(:,3), '-', 'Color', [c.yellow 0.95], 'LineWidth', 2.0 * lw);
end
scatter3(ax, E.vehicle(1), E.vehicle(2), E.vehicle(3) + 0.06, 110, 'o', 'MarkerFaceColor', c.yellow, ...
    'MarkerFaceAlpha', 0.22, 'MarkerEdgeColor', 'none');
scatter3(ax, E.vehicle(1), E.vehicle(2), E.vehicle(3) + 0.06, 20, 'o', 'MarkerFaceColor', c.yellow, ...
    'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.7);
end
