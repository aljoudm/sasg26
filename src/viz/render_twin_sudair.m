function png = render_twin_sudair(dpi, distScale)
% RENDER_TWIN_SUDAIR  Stage E. 3D digital twin of Sudair PV in the DAS-map main_static style (light theme): satellite texture draped on the
% Copernicus DEM, fence fibre coloured by zone, interrogator in the substation/control building with its two channels, 380 kV substation (Hot),
% one intrusion (detected -> human -> ALARM), one vehicle on the access road (logged), status panel, DAS trace inset. Cameras only as
% verification asset (none placed here), NO drones / UAVs / patrols. Output: poster_figs/twin3d.png (+ .pdf), ~1.74:1.
if nargin < 1, dpi = 300; end
c = sasg_config();  cfg = viz_cfg('light');  if nargin > 1, cfg.camera.dist = cfg.camera.dist * distScale; end
th = cfg.theme;  col = cfg.col;  zc = cfg.zoneCol;  lw = cfg.gfx;  fn = cfg.font;
tcfg = prepare_terrain_sudair();  tcfg.imageryCredit = cfg.imageryCredit;
T = load_terrain(tcfg);  scene.T = T;  scene.cfg = cfg;  scene.th = th;
F = load(fullfile(c.resDir, 'placement.mat')).F;  Sc = load(fullfile(c.resDir, 'scenario.mat')).Sc;
Zs = load(fullfile(c.zonesDir, 'zones.mat'));  Z = Zs.Z;  S = run_das_sudair();
lift = 0.012;
X = T.toX(F.lon);  Y = T.toY(F.lat);  H = T.heightXY(X, Y);  Zf = H + lift;
% zone per fibre point = zone of the nearest boundary piece (zone frame -> km)
px = Z.piece.x / 1e3;  py = Z.piece.y / 1e3;  kzx = Zs.G.kx / 1e3;  kzy = Zs.G.ky / 1e3;
fxz = (F.lon - Zs.G.lon0) * kzx;  fyz = (F.lat - Zs.G.lat0) * kzy;
[~, nn] = min((fxz - px') .^ 2 + (fyz - py') .^ 2, [], 2);  zone = Z.zone(Z.piece.cell(nn));
%% figure
W = round(cfg.figSizeIn(1) * 96);  Hh = round(cfg.figSizeIn(2) * 96);
fig = figure('Color', th.bg, 'Position', [60 40 W Hh], 'Units', 'pixels', 'Visible', 'off');
ax = axes(fig, 'Position', [0 0 1 1]);  hold(ax, 'on');
draw_terrain(ax, scene, 'satellite', true);
% fibre by zone (glow + core), closed ring
xr = [X; X(1)];  yr = [Y; Y(1)];  zr = [Zf; Zf(1)];  zn = [zone; zone(1)];
for z = 1:3
    m = zn == z;  m2 = m(1:end-1) & m(2:end);  xs = xr; ys = yr; zs = zr;  xs([false; ~m2]) = NaN;  ys([false; ~m2]) = NaN;  zs([false; ~m2]) = NaN;
    plot3(ax, xs, ys, zs, '-', 'Color', [zc(z, :) 0.30], 'LineWidth', 5.5 * lw);
    plot3(ax, xs, ys, zs + 0.002, '-', 'Color', zc(z, :), 'LineWidth', 1.9 * lw);
end
% substation polygon (Hot) draped
Ssub = load(fullfile(c.dataDir, 'substations.mat')).S;  sub = Ssub([Ssub.id] == c.subWayId);
sx = T.toX(sub.g(:, 2));  sy = T.toY(sub.g(:, 1));
patch(ax, sx, sy, T.heightXY(sx, sy) + 0.006, [1 1 1], 'FaceAlpha', 0.55, 'EdgeColor', zc(3, :), 'LineWidth', 1.6 * lw);
% interrogator at the building + lead-ins + channels
bx = T.toX(F.building(2));  by = T.toY(F.building(1));  bz = T.heightXY(bx, by);
ex = X(F.entryIdx);  ey = Y(F.entryIdx);  ez = Zf(F.entryIdx);
plot3(ax, [bx ex], [by ey], [bz + 0.04 ez], '-', 'Color', th.frame, 'LineWidth', 1.4 * lw);
plot3(ax, [bx bx], [by by], [bz bz + 0.12], '-', 'Color', th.frame, 'LineWidth', 1.4 * lw);
scatter3(ax, bx, by, bz + 0.12, 70, 's', 'MarkerFaceColor', col.iu, 'MarkerEdgeColor', th.frame, 'LineWidth', 1.1);
for k = 1:2    % channel direction arrowheads ~ 400 m from the entry
    idx = F.ch(k).idx;  q = idx(min(25, numel(idx)));  q2 = idx(min(26, numel(idx)));
    quiver3(ax, X(q), Y(q), Zf(q) + 0.01, X(q2) - X(q), Y(q2) - Y(q), 0, 0, 'Color', th.frame, 'LineWidth', 1.3, 'MaxHeadSize', 6000, 'Autoscale', 'off');
end
% intrusion
it = Sc.intr;  ix = X(it.idx);  iy = Y(it.idx);  iz = H(it.idx);  o = it.outward;  tl = 0.80;
tx = ix + o(1) * linspace(tl, -0.35, 30)';  ty = iy + o(2) * linspace(tl, -0.35, 30)';
[bx2, by2] = meshgrid(linspace(-0.6, 0.6, 40));  r2 = hypot(bx2, by2);
surface(ax, ix + bx2, iy + by2, T.heightXY(ix + bx2, iy + by2) + 0.012, cat(3, ones(size(r2)) * col.red(1), ones(size(r2)) * col.red(2), ones(size(r2)) * col.red(3)), ...
    'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceAlpha', 'interp', 'AlphaData', 0.6 * max(1 - r2 / 0.6, 0) .^ 1.4, 'AlphaDataMapping', 'none');
plot3(ax, tx, ty, T.heightXY(tx, ty) + 0.016, ':', 'Color', [1 0.45 0.4], 'LineWidth', 2.2 * lw);
for rr = [0.15 0.3 0.45]
    a = linspace(0, 2 * pi, 60)';  plot3(ax, ix + rr * cos(a), iy + rr * sin(a), T.heightXY(ix + rr * cos(a), iy + rr * sin(a)) + 0.018, '-', 'Color', [col.red 0.9 - 0.9 * rr], 'LineWidth', 1.4 * lw);
end
scatter3(ax, tx(1), ty(1), T.heightXY(tx(1), ty(1)) + 0.02, 34, 'o', 'MarkerFaceColor', col.red, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.9);
% vehicle on the access road (highlight the OSM road)
Rr = load(fullfile(c.dataDir, 'roads_osm.mat')).roads;  rd = Rr(Sc.veh.road_k);  rx = T.toX(rd.lon);  ry = T.toY(rd.lat);
plot3(ax, rx, ry, T.heightXY(rx, ry) + 0.01, '-', 'Color', [col.yellow 0.95], 'LineWidth', 2.0 * lw);
vx = T.toX(Sc.veh.lon);  vy = T.toY(Sc.veh.lat);
scatter3(ax, vx, vy, T.heightXY(vx, vy) + 0.02, 120, 'o', 'MarkerFaceColor', col.yellow, 'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor', 'none');
scatter3(ax, vx, vy, T.heightXY(vx, vy) + 0.02, 24, 'o', 'MarkerFaceColor', col.yellow, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.7);
% camera view (DAS-map: target = centre of the fibre path bbox)
axis(ax, 'off');  ax.DataAspectRatio = [1 1 1];  ax.Clipping = 'off';
mg = 2.5;  ax.XLim = [min(X) - mg, max(X) + mg];  ax.YLim = [min(Y) - mg, max(Y) + mg];  ax.ZLim = [0 8];
tgt = [mean([min(X) max(X)]), mean([min(Y) max(Y)]), mean(Zf)];
set_camera(ax, tgt, cfg.camera);  drawnow;
% labels (outside the fibre where possible)
lab = struct('size', 7.5, 'weight', 'bold');  ar = char(8594);
ztop = max(Zf) + 0.4;
halo_text(ax, ix + o(1) * 1.5, iy + o(2) * 1.5, iz + 0.25, ['Intruder: detected ' ar ' human ' ar ' ALARM'], lab, th.intLbl, scene);
plot3(ax, [ix ix + o(1) * 1.3], [iy iy + o(2) * 1.3], [iz + 0.03 iz + 0.22], '-', 'Color', [th.intLbl 0.8], 'LineWidth', 0.8);
halo_text(ax, vx + 0.4, vy + 2.3, ztop + 0.3, ['Vehicle on access road ' ar ' logged'], lab, th.aniLbl, scene);
plot3(ax, [vx vx + 0.4], [vy vy + 2.3], [bz + 0.03 ztop + 0.28], '-', 'Color', [th.aniLbl 0.8], 'LineWidth', 0.8);
halo_text(ax, bx - 2.6, by + 1.2, ztop + 0.1, '380 kV substation (Hot)', lab, th.lblText, scene);
plot3(ax, [bx - 1.6 sx(1)], [by + 1.1 sy(1)], [ztop + 0.08 bz + 0.02], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.6);
halo_text(ax, bx - 2.0, by - 0.5, ztop - 0.1, 'Interrogator + control room', lab, th.iuLbl, scene);
plot3(ax, [bx - 1.1 bx], [by - 0.45 by], [ztop - 0.12 bz + 0.12], '-', 'Color', [th.iuLbl 0.7], 'LineWidth', 0.6);
%% panels
Lstat = [0.012 0.02 0.235 0.27];
bg = panel_axes(fig, Lstat, th, 1);  hin = Lstat(4) * cfg.figSizeIn(2);  Y_ = @(inch) 1 - inch / hin;
tx_ = @(xx, inch, s, cc, st, ha) text(bg, xx, Y_(inch), s, 'Color', cc, 'FontName', fn.name, 'FontSize', st.size, 'FontWeight', st.weight, 'HorizontalAlignment', ha, 'VerticalAlignment', 'middle');
bold = struct('size', fn.panel.size, 'weight', 'bold');
tx_(0.05, 0.11, 'STATUS', th.muted, fn.title, 'left');
rows = {'Fibre length', sprintf('%.1f km', F.fibreTotalKm); 'Interrogator', sprintf('%d', F.N_IU); 'Channels (active / spare)', sprintf('%d / %d', F.N_ch_active, F.N_ch_spare);
        'Sensing points (fibre / 2 m)', sprintf('%s', regexprep(sprintf('%d', F.N_sensing), '(\d)(?=(\d{3})+$)', '$1,')); 'Cameras', 'none placed'};
y = 0.27;  for i = 1:size(rows, 1), tx_(0.05, y, rows{i, 1}, th.muted, fn.panel, 'left');  tx_(0.95, y, rows{i, 2}, th.text, bold, 'right');  y = y + 0.135; end
tx_(0.05, hin - 0.1, 'Simulated scenario; verification by cameras only', th.muted, fn.note, 'left');
% DAS trace inset
Ltr = [0.655 0.02 0.335 0.27];
bg2 = panel_axes(fig, Ltr, th, 1);  text(bg2, 0.04, 0.9, [char(966) '-OTDR SIMULATION, FEBUS A1-NEO'], 'Color', th.muted, 'FontName', fn.name, 'FontSize', fn.title.size, 'FontWeight', 'bold');
ta = axes(fig, 'Position', [Ltr(1) + 0.13 * Ltr(3), Ltr(2) + 0.25 * Ltr(4), 0.82 * Ltr(3), 0.46 * Ltr(4)], 'Color', 'none');  hold(ta, 'on');
plot(ta, S.z / 1e3, S.act, '-', 'Color', th.trace, 'LineWidth', 0.5);  yline(ta, S.thr, '--', 'Color', th.thr, 'LineWidth', 0.7);
for i = 1:numel(S.tab)
    t = string(S.tab(i).type);  cc = th.muted;  if t == "walk", cc = th.intLbl; elseif t == "vehicle", cc = th.aniLbl; end
    plot(ta, S.tab(i).z_est / 1e3, S.tab(i).peak_nm, 'o', 'MarkerSize', 3, 'MarkerFaceColor', cc, 'MarkerEdgeColor', 'none');
end
ta.FontName = fn.name;  ta.FontSize = fn.note.size;  ta.XColor = th.muted;  ta.YColor = th.muted;  ta.TickDir = 'out';  ta.Box = 'off';
xlim(ta, [0 S.z(end) / 1e3]);  ylim(ta, [0 max(S.act) * 1.15]);  xlabel(ta, 'Distance along channel (km)', 'FontSize', fn.note.size);  ylabel(ta, 'nm rms', 'FontSize', fn.note.size);
rowsT = {th.intLbl, ['walking = map intruder ' ar ' ALARM']; th.aniLbl, ['vehicle = map vehicle ' ar ' logged']};
for k = 1:2, yy = 0.10 - 0 + (k - 1) * 0; end
text(bg2, 0.04, 0.78, ['\color[rgb]{' sprintf('%.2f %.2f %.2f', th.intLbl) '}' char(9679) ' \color[rgb]{' sprintf('%.2f %.2f %.2f', th.text) '}walking = intruder   \color[rgb]{' sprintf('%.2f %.2f %.2f', th.aniLbl) '}' char(9679) ' \color[rgb]{' sprintf('%.2f %.2f %.2f', th.text) '}vehicle'], 'FontName', fn.name, 'FontSize', fn.note.size, 'Interpreter', 'tex', 'VerticalAlignment', 'middle');
% legend (zones) upper-left, credit, north arrow
oa = axes(fig, 'Position', [0 0 1 1], 'Color', 'none');  hold(oa, 'on');  oa.XLim = [0 1];  oa.YLim = [0 1];  axis(oa, 'off');
names = {sprintf('Hot fence (%.1f km)', Z.kmZone(3)), sprintf('Neutral fence (%.1f km)', Z.kmZone(2)), sprintf('Cold fence (%.1f km)', Z.kmZone(1))};
for k = 1:3
    yy = 0.925 - (k - 1) * 0.042;  plot(oa, [0.015 0.045], [yy yy], '-', 'Color', zc(4 - k, :), 'LineWidth', 2.4);
    text(oa, 0.052, yy, names{k}, 'Color', th.lblText, 'FontName', fn.name, 'FontSize', fn.panel.size, 'VerticalAlignment', 'middle');
end
text(oa, 0.451, 0.004, strrep(cfg.imageryCredit, ' Terrain:', [newline 'Terrain:']), 'Color', th.credit, 'FontName', fn.name, 'FontSize', fn.note.size, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
north_arrow(oa, [0.965, 0.80], 0.10, th.text, th.bg, cfg);
fig.Position = [60 40 W Hh];  drawnow;  pause(0.3);
if ~exist(c.figDir, 'dir'), mkdir(c.figDir); end
png = fullfile(c.figDir, 'twin3d.png');
exportgraphics(fig, png, 'Resolution', dpi, 'BackgroundColor', th.bg);
if dpi >= 300, exportgraphics(fig, strrep(png, '.png', '.pdf'), 'ContentType', 'image', 'Resolution', dpi, 'BackgroundColor', th.bg); end
close(fig);
fprintf('twin3d: camera dist = %.3f (53 x %.2f/%.2f km diag, scale %.2f) -> %s\n', cfg.camera.dist, cfg.diag_sudair_km, cfg.diag_makkah_km, cfg.camDistScale, png);
end
