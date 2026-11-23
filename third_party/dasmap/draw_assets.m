function draw_assets(ax, scene, lw)
% DRAW_ASSETS  Interrogator units and UAVs (hovering, downward sensing cone). UAV altitude and
% cone size are display values, NOT to scale.
cfg = scene.cfg;  c = cfg.col;  th = scene.th;  F = scene.fibre;  T = scene.T;  ks = cfg.uiScale;

for k = 1:numel(F.iuIdx)                                   % IU: pole + square head + ground ring
    x = F.iuX(k);  y = F.iuY(k);  z0 = F.iuZ(k);  h = 1.4;
    plot3(ax, [x x], [y y], [z0 z0 + h], '-', 'Color', [c.cyan 0.7], 'LineWidth', 1.4 * lw);
    drawRing(ax, T, x, y, 0.55, [c.cyan 0.9], 1.4 * lw);
    scatter3(ax, x, y, z0 + h, 46 * ks^2, 's', 'MarkerFaceColor', c.iu, 'MarkerEdgeColor', th.frame, 'LineWidth', 0.9 * ks, 'Tag', 'iu');
end
scatter3(ax, F.segEndX, F.segEndY, F.segEndZ + 0.05, 14 * ks^2, 'd', 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', th.frame, ...
    'LineWidth', 0.5 * ks, 'Tag', 'segend');                  % fibre-segment ends (each channel serves one segment)
if isfield(scene, 'anim') && scene.anim, return; end     % interactive version animates the UAVs itself

for k = 1:numel(scene.uav)
    u = scene.uav(k);
    a = linspace(0, 2*pi, 48)';   rx = u.x + cfg.uavConeR * cos(a);   ry = u.y + cfg.uavConeR * sin(a);
    rz = T.heightXY(rx, ry) + 0.03;
    V = [u.x u.y u.z; rx ry rz];   Fc = [ones(47,1), (2:48)', (3:49)'];  Fc(end, 3) = 2;
    patch(ax, 'Faces', Fc, 'Vertices', V, 'FaceColor', c.cyan, 'FaceAlpha', 0.20, 'EdgeColor', 'none');
    plot3(ax, rx, ry, rz, '-', 'Color', [c.cyan 0.9], 'LineWidth', 1.5 * lw);
    for q = 1:6:48, plot3(ax, [u.x rx(q)], [u.y ry(q)], [u.z rz(q)], '-', 'Color', [c.cyan 0.45], 'LineWidth', 0.9 * lw); end
    arm = 0.85;  ang = [pi/4 3*pi/4 5*pi/4 7*pi/4];
    for q = 1:4
        tx = u.x + arm * cos(ang(q));   ty = u.y + arm * sin(ang(q));
        plot3(ax, [u.x tx], [u.y ty], [u.z u.z], '-', 'Color', c.uav, 'LineWidth', 2.6 * lw);
        scatter3(ax, tx, ty, u.z, 16, 'o', 'MarkerFaceColor', c.uav, 'MarkerEdgeColor', c.cyan, 'LineWidth', 0.6);
    end
    scatter3(ax, u.x, u.y, u.z, 18, 'o', 'MarkerFaceColor', c.cyan, 'MarkerEdgeColor', 'none');
end
end

function drawRing(ax, T, x, y, r, col, lw)
a = linspace(0, 2*pi, 60)';   rx = x + r * cos(a);   ry = y + r * sin(a);
plot3(ax, rx, ry, T.heightXY(rx, ry) + 0.03, '-', 'Color', col, 'LineWidth', lw);
end
