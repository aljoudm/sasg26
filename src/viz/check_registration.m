function check_registration()
% CHECK_REGISTRATION  Top-down proof view (orthographic, el = 90, vertical exaggeration 1): the boundary as a 1 px line over the drawn terrain
% surface (the same meshes / textures as the twin). Writes poster_figs/check_registration_{NW_strip,substation_notch,east_edge}.png.
c = sasg_config();  sc = build_twin_scene('light');  T = sc.T;  vp = sc.vp;
% rebuild the terrain with exaggeration 1 (same textures)
tc = sc.tcfg;  tc.VERT_EXAG = 1;  T1 = load_terrain(tc);
mb = T1.base;  md = T1.mashaer;
Gd = griddedInterpolant({md.Y(:, 1), md.X(1, :)}, md.Z, 'linear', 'none');  Gb = griddedInterpolant({mb.Y(:, 1), mb.X(1, :)}, mb.Z, 'linear', 'nearest');
ring = readmatrix(c.boundaryCsv);  bx = T1.toX(ring(:, 2));  by = T1.toY(ring(:, 1));
z = Gd(by, bx);  w = isnan(z);  z(w) = Gb(by(w), bx(w));
[~, iN] = max(by);
ctr = [bx(iN) - 0.15, by(iN) - 0.12; sc.fibre.iuX, sc.fibre.iuY; sc.events.cross(1), sc.events.cross(2)];     % km
names = {'NW_strip', 'substation_notch', 'east_edge'};  hw = 0.40;  hh = 0.267;
sc1 = struct('T', T1, 'vp', vp);
for q = 1:3
    fig = figure('Color', 'w', 'Position', [10 10 1200 800], 'Units', 'pixels', 'Visible', 'off');
    ax = axes(fig, 'Position', [0 0 1 1]);  hold(ax, 'on');
    draw_terrain_sudair(ax, sc1);
    plot3(ax, bx, by, z + 0.02, '-', 'Color', [1 0 0], 'LineWidth', 0.75);                 % 1 px at 96 dpi
    ax.Projection = 'orthographic';  view(ax, 0, 90);  axis(ax, 'off');  ax.DataAspectRatio = [1 1 1];
    xlim(ax, ctr(q, 1) + [-hw hw]);  ylim(ax, ctr(q, 2) + [-hh hh]);  zlim(ax, [0 3]);
    fig.PaperPositionMode = 'auto';  drawnow;
    print(fig, fullfile(c.figDir, ['check_registration_' names{q} '.png']), '-dpng', '-r96');  close(fig);
end
fprintf('registration crops written (0.8 km x 0.53 km each, 1200 x 800 px, el = 90, orthographic, VE 1)\n');
end
