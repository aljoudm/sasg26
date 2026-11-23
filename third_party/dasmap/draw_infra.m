function draw_infra(ax, scene, lw)
% DRAW_INFRA  Road entry points (existing checkpoints), CCTV with field-of-view wedges, patrols and the
% C2 centre with data links from each interrogator. Counts and positions are ILLUSTRATIVE (see compute_assets).
cfg = scene.cfg;  c = cfg.col;  th = scene.th;  A = scene.assets;  T = scene.T;  F = scene.fibre;  ks = cfg.uiScale;
edge = [0.10 0.12 0.15];

for k = 1:numel(A.cctv)                                           % CCTV field-of-view wedges on the ground
    q = A.cctv(k);   half = deg2rad(cfg.camFovDeg / 2);
    a = q.heading + linspace(-half, half, 18)';
    wx = q.x + cfg.camRangeKm * cos(a);   wy = q.y + cfg.camRangeKm * sin(a);
    wz = T.heightXY(wx, wy) + 0.04;
    V = [q.x q.y q.gz + 0.04; wx wy wz];   Fc = [ones(17, 1), (2:18)', (3:19)'];
    patch(ax, 'Faces', Fc, 'Vertices', V, 'FaceColor', c.cctv, 'FaceAlpha', 0.24, 'EdgeColor', 'none');
    plot3(ax, [q.x; wx; q.x], [q.y; wy; q.y], [q.gz + 0.04; wz; q.gz + 0.04], '-', 'Color', [c.cctv 0.9], 'LineWidth', 0.6 * lw / 0.55 * 0.55);
end
scatter3(ax, [A.cctv.x], [A.cctv.y], [A.cctv.z] + 0.12, 14 * ks^2, 'o', 'MarkerFaceColor', c.cctv, 'MarkerEdgeColor', edge, 'LineWidth', 0.5);

scatter3(ax, A.entry(:,1), A.entry(:,2), A.entry(:,3) + 0.16, 30 * ks^2, 'd', 'MarkerFaceColor', c.entry, ...
    'MarkerEdgeColor', edge, 'LineWidth', 0.8);                    % road entry points

scatter3(ax, A.patrol(:,1), A.patrol(:,2), A.patrol(:,3) + 0.10, 26 * ks^2, 's', 'MarkerFaceColor', c.patrol, ...
    'MarkerEdgeColor', edge, 'LineWidth', 0.7 * ks, 'Tag', 'patrols');                    % patrols

for k = 1:numel(F.iuIdx)                                          % C2 data links (arcs above the terrain)
    p0 = [F.iuX(k) F.iuY(k) F.iuZ(k) + 1.4];   p1 = A.c2 + [0 0 1.0];
    t = linspace(0, 1, 60)';
    x = p0(1) + (p1(1) - p0(1)) * t;   y = p0(2) + (p1(2) - p0(2)) * t;
    z = max(p0(3) + (p1(3) - p0(3)) * t + 2.6 * sin(pi * t), T.heightXY(x, y) + 0.4);
    plot3(ax, x, y, z, '-', 'Color', [c.cyan 0.70], 'LineWidth', 1.1 * lw);
end
plot3(ax, [A.c2(1) A.c2(1)], [A.c2(2) A.c2(2)], [A.c2(3) A.c2(3) + 1.0], '-', 'Color', [c.c2 0.9], 'LineWidth', 1.2 * lw);
scatter3(ax, A.c2(1), A.c2(2), A.c2(3) + 1.0, 130 * ks^2, 'p', 'MarkerFaceColor', c.c2, 'MarkerEdgeColor', edge, 'LineWidth', 0.8);
end
