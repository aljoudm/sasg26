function png = render_twin_sudair(dpi, mode, variant, distScale)
% RENDER_TWIN_SUDAIR  Stage E (restyled, fix round). 3D digital twin of Sudair PV from the DAS-map drawing code (third_party/dasmap unchanged;
% adapted copies in src/viz). mode 'main' | 'zoom'; variant 'clean' (map only: poster_figs/twin3d.png, twin3d_zoom.png) | 'panels'
% (poster_figs/twin3d_panels.png: panels in a strip below the map). Everything is draped on the drawn DEM surface. Real data only.
% No drones, UAVs, patrols or C2. Cameras: none placed.
if nargin < 1, dpi = 300; end
if nargin < 2, mode = 'main'; end
if nargin < 3, variant = 'clean'; end
if nargin < 4, distScale = 1.1; end
c = sasg_config();  sc = build_twin_scene('light');  cfg = sc.cfg;  th = cfg.theme;  col = cfg.col;  zc = cfg.zoneCol;  lw = cfg.gfx;  fn = cfg.font;  vp = sc.vp;
T = sc.T;  F = sc.fibre;  E = sc.events;  isZoom = strcmp(mode, 'zoom');  isPan = strcmp(variant, 'panels') && ~isZoom;
if isZoom, asp = 4 / 3; else, asp = 1.74; end
Hh = 480;  W = round(Hh * asp);
if isPan, fc = th.bg; else, fc = vp.haze_col; end
fig = figure('Color', fc, 'Position', [10 10 W Hh], 'Units', 'pixels', 'Visible', 'off');
drawnow;  Hh = fig.Position(4);  W = fig.Position(3);  cfg.figSizeIn = [W Hh] / 96;  sc.cfg = cfg;
if isPan, ap = [0 0.32 1 0.68]; else, ap = [0 0 1 1]; end
ax = axes(fig, 'Position', ap, 'Color', vp.haze_col);  hold(ax, 'on');
%% terrain (+ real contours, real OSM waterways)
draw_terrain_sudair(ax, sc);
X = F.x;  Y = F.y;  bb = [min(X) max(X) min(Y) max(Y)] + [-3 3 -3 3];
S0 = load(sc.tcfg.demMat);  latA = flipud(S0.lat(:));  Zc = imgaussfilt(flipud(double(S0.Z)), 1.5);
lev = ceil(min(Zc(:)) / vp.contour_m) * vp.contour_m : vp.contour_m : max(Zc(:));
Cm = contourc(double(S0.lon(:))', double(latA)', Zc, lev);  k = 1;  segs = struct('lvl', {}, 'x', {}, 'y', {});
while k < size(Cm, 2)
    n = Cm(2, k);  lvl = Cm(1, k);  p = Cm(:, k + 1:k + n);  x = T.toX(p(1, :))';  y = T.toY(p(2, :))';  k = k + n + 1;
    in = x >= bb(1) & x <= bb(2) & y >= bb(3) & y <= bb(4);  x(~in) = NaN;  y(~in) = NaN;
    if nnz(in) > 6, segs(end + 1) = struct('lvl', lvl, 'x', x, 'y', y); end %#ok<AGROW>
end
for s = segs, plot3(ax, s.x, s.y, T.heightXY(s.x, s.y) + 0.004, '-', 'Color', [1 1 1 0.42], 'LineWidth', 0.35); end
nWw = 0;  wf = fullfile(c.dataDir, 'osm_waterways.json');
if isfile(wf)
    dw = jsondecode(fileread(wf, 'Encoding', 'UTF-8'));
    for q = 1:numel(dw.elements)
        if iscell(dw.elements), e = dw.elements{q}; else, e = dw.elements(q); end
        if ~isfield(e, 'geometry'), continue; end
        wx = T.toX([e.geometry.lon]');  wy = T.toY([e.geometry.lat]');  in = wx >= bb(1) & wx <= bb(2) & wy >= bb(3) & wy <= bb(4);  wx(~in) = NaN;  wy(~in) = NaN;
        if any(in), plot3(ax, wx, wy, T.heightXY(wx, wy) + 0.004, '-', 'Color', [0.30 0.45 0.62 0.85], 'LineWidth', 0.6);  nWw = nWw + 1; end
    end
end
%% risk glow (outside the fence only), zone bands (+-50 m, draped), fibre, assets, events
if ~isZoom, draw_risk_sudair(ax, sc); end
n = F.n;  sgn = sign(sum((X - circshift(X, -1)) .* (Y + circshift(Y, -1))));
xs = movmean([X; X; X], 9);  ys = movmean([Y; Y; Y], 9);  xs = xs(n + 1:2 * n);  ys = ys(n + 1:2 * n);
tx = circshift(xs, -1) - circshift(xs, 1);  ty = circshift(ys, -1) - circshift(ys, 1);  tn = hypot(tx, ty);  nx = ty ./ tn * sgn;  ny = -tx ./ tn * sgn;
xo = X + vp.band_km * nx;  yo = Y + vp.band_km * ny;  xi = X - vp.band_km * nx;  yi = Y - vp.band_km * ny;
for z = 1:3
    m = F.zone == z;  m = m & circshift(m, -1);  idx = [(1:n)'; 1];  mm = [m; m(1)];
    XB = [xi(idx)'; xo(idx)'];  YB = [yi(idx)'; yo(idx)'];  XB(:, ~mm) = NaN;  YB(:, ~mm) = NaN;
    ZB = [T.heightXY(xi(idx), yi(idx))'; T.heightXY(xo(idx), yo(idx))'] + 0.003;
    surface(ax, XB, YB, ZB, 'FaceColor', zc(z, :), 'EdgeColor', 'none', 'FaceAlpha', vp.band_alpha);
end
draw_fibre_sudair(ax, sc, lw);
patch(ax, sc.sub.x, sc.sub.y, T.heightXY(sc.sub.x, sc.sub.y) + 0.004, [1 1 1], 'FaceAlpha', 0.45, 'EdgeColor', zc(3, :), 'LineWidth', 1.2 * lw);
bx = F.iuX;  by = F.iuY;  bz = F.iuZ;  ex = X(sc.F0.entryIdx);  ey = Y(sc.F0.entryIdx);  ez = F.z(sc.F0.entryIdx);
plot3(ax, [bx ex], [by ey], [bz + 0.006 ez], '-', 'Color', [col.cyan 0.9], 'LineWidth', 1.2 * lw);
draw_assets_sudair(ax, sc, lw);
if isZoom, sc.heatScale = 0.30; end
draw_events_sudair(ax, sc, lw);
%% camera (az 180, el 30, fov 30, perspective, target = fibre bbox centre; only dist scaled)
axis(ax, 'off');  ax.DataAspectRatio = [1 1 1];  ax.Clipping = 'off';
mg = 2.5;  ax.XLim = [min(X) - mg, max(X) + mg];  ax.YLim = [min(Y) - mg, max(Y) + mg];  ax.ZLim = [0 8];
cam = cfg.camera;  cam.dist = cam.dist * distScale;
if isZoom, tgt = [E.cross(1) + 0.05, E.cross(2) - 0.05, E.cross(3) + 0.05];  cam.dist = 1.9;
else, tgt = [mean([min(X) max(X)]), mean([min(Y) max(Y)]), mean(F.z)]; end
set_camera(ax, tgt, cam);  drawnow;
%% labels: halo text, short leader lines, placed outside the fibre
lab = struct('size', 7.5, 'weight', 'bold');  arr = char(8594);  AI = ai_labels();  o = sc.Sc.intr.outward;  ix = E.cross(1);  iy = E.cross(2);  iz = E.cross(3);
ztop = max(F.z) + 0.30;
if isZoom
    halo_text(ax, ix + o(1) * 0.75, iy + o(2) * 0.75, iz + 0.22, AI.intr, lab, th.intLbl, sc);
    plot3(ax, [ix + o(1) * 0.15, ix + o(1) * 0.55], [iy + o(2) * 0.15, iy + o(2) * 0.55], [iz + 0.01 iz + 0.2], '-', 'Color', [th.intLbl 0.8], 'LineWidth', 0.7);
else
    halo_text(ax, ix + o(1) * 1.3, iy + o(2) * 1.3, iz + 0.30, AI.intr, lab, th.intLbl, sc);
    plot3(ax, [ix + o(1) * 0.1, ix + o(1) * 0.8], [iy + o(2) * 0.1, iy + o(2) * 0.8], [iz + 0.01 iz + 0.27], '-', 'Color', [th.intLbl 0.8], 'LineWidth', 0.7);
    vx = E.vehicle(1);  vy = E.vehicle(2);  vz = E.vehicle(3);
    halo_text(ax, vx + 0.2, vy + 1.6, ztop + 0.25, AI.veh, lab, th.aniLbl, sc);
    plot3(ax, [vx vx + 0.2], [vy vy + 1.2], [vz + 0.01 ztop + 0.2], '-', 'Color', [th.aniLbl 0.8], 'LineWidth', 0.7);
    halo_text(ax, bx - 2.6, by + 0.9, ztop + 0.15, '380 kV substation (Hot)', lab, th.lblText, sc);
    plot3(ax, [bx - 1.5 bx - 0.12], [by + 0.85 by + 0.1], [ztop + 0.12 bz + 0.02], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.6);
    halo_text(ax, bx - 2.6, by - 0.15, ztop - 0.05, 'Interrogator + control room', lab, th.iuLbl, sc);
    plot3(ax, [bx - 1.4 bx - 0.1], [by - 0.15 by - 0.02], [ztop - 0.07 bz + 0.1], '-', 'Color', [th.iuLbl 0.7], 'LineWidth', 0.6);
    pb = [min(X) max(X) min(Y) max(Y)];  used = [];
    for q = 1:numel(segs)      % 2-3 real contours labelled with their elevation, near the southern edge of the plant
        s = segs(q);  if numel(used) >= vp.contour_label || any(abs(s.lvl - used) < 1e-9), continue; end
        ok = find(s.x >= pb(1) - 0.5 & s.x <= pb(2) & s.y >= pb(3) - 2.5 & s.y < pb(3) + 0.8);  if numel(ok) < 4, continue; end
        j = ok(round(end / 2));  halo_text(ax, s.x(j), s.y(j), T.heightXY(s.x(j), s.y(j)) + 0.03, sprintf('%d m', round(s.lvl)), struct('size', 6, 'weight', 'bold'), [0.25 0.25 0.25], sc);  used(end + 1) = s.lvl; %#ok<AGROW>
    end
end
%% panels (variant 'panels' only), credit, north arrow
credit = [cfg.imageryCredit ' Vertical exaggeration x' num2str(vp.VERT_EXAG) '; hillshade from the DEM.'];
oa = axes(fig, 'Position', [0 0 1 1], 'Color', 'none');  hold(oa, 'on');  oa.XLim = [0 1];  oa.YLim = [0 1];  axis(oa, 'off');
if isPan
    sy = 0.065;  sh = 0.25;
    draw_status_sudair(fig, [0.012 sy 0.29 sh], sc);
    draw_trace_sudair(fig, [0.655 sy 0.335 sh], sc);
    lg = panel_axes(fig, [0.312 sy 0.333 sh], th, 1);
    items = {sprintf('Hot fence %.1f km', sc.Z.kmZone(3)), sprintf('Neutral fence %.1f km', sc.Z.kmZone(2)), sprintf('Cold fence %.1f km', sc.Z.kmZone(1)), 'Weak-coverage glow', ...
             'DAS fibre (energy)', 'Light pulse', 'Interrogator / seg. end', 'Intruder / vehicle'};
    for q = 1:8
        cx = 0.03 + 0.50 * (q > 4);  cy = 0.86 - mod(q - 1, 4) * 0.25;
        switch q
            case {1, 2, 3}, patch(lg, cx + [0 0.07 0.07 0], cy + [-0.07 -0.07 0.07 0.07], zc(4 - q, :), 'FaceAlpha', 0.55, 'EdgeColor', zc(4 - q, :));
            case 4, patch(lg, cx + [0 0.035 0.035 0], cy + [-0.07 -0.07 0.07 0.07], col.riskLo, 'EdgeColor', 'none'); patch(lg, cx + [0.035 0.07 0.07 0.035], cy + [-0.07 -0.07 0.07 0.07], col.riskHi, 'EdgeColor', 'none');
            case 5, for r = 1:4, plot(lg, cx + [0 0.0175] + (r - 1) * 0.0175, [cy cy], '-', 'Color', col.fibreCmap(round(1 + (r - 1) * 85), :), 'LineWidth', 1.6); end
            case 6, plot(lg, cx + [0 0.07], [cy cy], '-', 'Color', [col.cyan 0.55], 'LineWidth', 3.0);  plot(lg, cx + [0 0.07], [cy cy], '-', 'Color', [1 1 1], 'LineWidth', 1.2);
            case 7, plot(lg, cx + 0.02, cy, 's', 'MarkerSize', 4.2, 'MarkerFaceColor', col.iu, 'MarkerEdgeColor', th.frame);  plot(lg, cx + 0.055, cy, 'd', 'MarkerSize', 3.6, 'MarkerFaceColor', col.yellow, 'MarkerEdgeColor', th.frame);
            case 8, plot(lg, cx + 0.02, cy, 'o', 'MarkerSize', 4.4, 'MarkerFaceColor', col.red, 'MarkerEdgeColor', th.text, 'LineWidth', 0.4);  plot(lg, cx + 0.055, cy, 'o', 'MarkerSize', 4, 'MarkerFaceColor', col.yellow, 'MarkerEdgeColor', th.text, 'LineWidth', 0.4);
        end
        text(lg, cx + 0.09, cy, items{q}, 'Color', th.text, 'FontName', fn.name, 'FontSize', fn.panel.size - 0.6, 'VerticalAlignment', 'middle');
    end
    text(oa, 0.5, 0.012, credit, 'Color', [0.3 0.33 0.37], 'FontName', fn.name, 'FontSize', fn.note.size - 0.3, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    north_arrow(oa, [0.968, 0.37], 0.07, th.text, th.bg, cfg);
else
    % clean: small attribution in a white semi-transparent box (bottom right) and a small N arrow only
    cl = strrep(strrep(credit, ' Terrain:', [newline 'Terrain:']), ' Vertical', [newline 'Vertical']);
    tt = text(oa, 0.994, 0.008, cl, 'Color', [0.25 0.28 0.32], 'FontName', fn.name, 'FontSize', fn.note.size - 0.4, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
    drawnow;  ee = tt.Extent;  pad = 0.004;
    pt = patch(oa, [ee(1) - pad ee(1) + ee(3) + pad ee(1) + ee(3) + pad ee(1) - pad], [ee(2) - pad ee(2) - pad ee(2) + ee(4) + pad ee(2) + ee(4) + pad], [1 1 1], 'FaceAlpha', 0.7, 'EdgeColor', 'none');
    uistack(tt, 'top');  uistack(pt, 'bottom');
    north_arrow(oa, [0.968, 0.84], 0.07, th.text, th.bg, cfg);
end
drawnow;  pause(0.3);
if ~exist(c.figDir, 'dir'), mkdir(c.figDir); end
if isZoom, nm = 'twin3d_zoom'; elseif isPan, nm = 'twin3d_panels'; else, nm = 'twin3d'; end
png = fullfile(c.figDir, [nm '.png']);
fig.PaperPositionMode = 'auto';  fig.InvertHardcopy = 'off';  print(fig, png, '-dpng', sprintf('-r%d', dpi));          % exact pixel size = figure size x dpi/96
if dpi >= 300, exportgraphics(fig, strrep(png, '.png', '.pdf'), 'ContentType', 'image', 'Resolution', dpi, 'BackgroundColor', fc); end
close(fig);
fprintf('%s: dist %.3f, VE x%g, waterways drawn %d, false-alarm fibre points %d -> %s\n', nm, cam.dist, vp.VERT_EXAG, nWw, sc.nFalse, png);
end
