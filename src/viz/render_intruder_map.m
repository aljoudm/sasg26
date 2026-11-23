function png = render_intruder_map(dpi)
% RENDER_INTRUDER_MAP  Stage E2. 2D satellite map of ONE simulated intruder: trajectory -> fence crossing -> DAS detection with its
% localisation-error ellipse -> DAS track linked to the nearest fixed-camera track inside its FOV cone -> control room.
% FIXED CAMERAS ONLY (no drones, no patrols, no person profiling / height). Geometry, ellipse sizes, camera spacing / range are
% ILLUSTRATIVE [ASSUMED]; the only quoted number is the full-das re-ID grid row (read from its CSV, read-only):
%   camera_source=fixed, spacing_m=20, pairs_share=0, position_error_m=1.0, clock_offset_s=0.2, crossing=False, camera_dropout=0.
if nargin < 1, dpi = 300; end
c = sasg_config();  cfg = viz_cfg('light');  th = cfg.theme;  fn = cfg.font;  zc = cfg.zoneCol;
F = load(fullfile(c.resDir, 'placement.mat')).F;  Sc = load(fullfile(c.resDir, 'scenario.mat')).Sc;  Zs = load(fullfile(c.zonesDir, 'zones.mat'));
S = run_das_sudair();
%% reid row (read-only source), verified, not typed in
rg = readtable('C:\Users\aljou\OneDrive\Desktop\full das\results\reid\reid_grid.csv', 'TextType', 'string');
sel = rg.camera_source == "fixed" & rg.spacing_m == 20 & rg.pairs_share == 0 & rg.position_error_m == 1 & rg.clock_offset_s == 0.2 & string(rg.crossing) == "False" & rg.camera_dropout == 0;
assert(nnz(sel) == 1, 'reid row not unique');  acc = rg.person_link_acc(sel);  rate = rg.person_link_rate(sel);
%% local frame (m) centred on the crossing
ky = 111195;  lat0 = Sc.intr.lat;  lon0 = Sc.intr.lon;  kx = ky * cosd(lat0);
toX = @(lon) (lon - lon0) * kx;  toY = @(lat) (lat - lat0) * ky;
fx = toX(F.lon);  fy = toY(F.lat);  t = Sc.intr.tangent;  o = Sc.intr.outward;      % tangent / outward in the SCENARIO frame (same orientation: east, north)
% scenario frame used kx at mean lat: equivalent to ours to < 1e-3, normalise anyway
t = t / norm(t);  o = o / norm(o);
hw = 170;  hh = 128;                                                      % half window [m]
%% imagery for the window (Esri export, cached, small)
imgFile = fullfile(c.dataDir, 'dem', 'tex_intruder.jpg');
if ~isfile(imgFile)
    la = lat0 + [-452 452] / ky;  lo = lon0 + [-600 600] / kx;     % Esri refuses very small extents: fetch 1.2 km, show the central window
    url = sprintf(['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=%.7f,%.7f,%.7f,%.7f&bboxSR=4326&imageSR=4326&size=1024,771&format=jpg&f=image'], lo(1), la(1), lo(2), la(2));
    websave(imgFile, url, weboptions('Timeout', 120, 'UserAgent', c.UA));
end
img = imread(imgFile);
%% scenario geometry (ILLUSTRATIVE)
p = @(d, l) [l * t(1) + d * o(1), l * t(2) + d * o(2)];                    % point at outward distance d, along-fence offset l
dd = linspace(135, -95, 90)';  ll = -0.30 * dd + 8 * sin(dd / 30);       % angled approach with a little weave
path = p(dd, ll);  path = [dd * 0 + 0 dd * 0 + 0] + [ll * t(1) + dd * o(1), ll * t(2) + dd * o(2)];
dcross = 0;  [~, ic] = min(abs(dd - dcross));  cross = path(ic, :);
% DAS track: only while within |d| <= 28 m of the fibre; along/across noise (fixed seed)
rng(c.seed);  sa = 5;  sc_ = 9;                                           % 1-sigma along / across the fence [m] [ASSUMED: ILLUSTRATIVE; engine position error <= 5 m]
iD = find(abs(dd) <= 28);  iD = iD(1:3:end);
nz = [randn(numel(iD), 1) * sa randn(numel(iD), 1) * sc_];
das = path(iD, :) + nz(:, 1) .* t + nz(:, 2) .* o;
% fixed cameras: spacing 20 m along the fence [reid row], 3 m inside, facing outward, FOV 90 deg, range 70 m [ASSUMED: ILLUSTRATIVE]
camL = (-60:20:60)';  camPos = p(-3 + 0 * camL, camL);  R = 55;  fov = 90;
[~, near] = min(hypot(camPos(:, 1) - cross(1), camPos(:, 2) - cross(2)));
hd = atan2(o(2), o(1));
inCone = @(q, k) hypot(q(:, 1) - camPos(k, 1), q(:, 2) - camPos(k, 2)) <= R & abs(mod(atan2(q(:, 2) - camPos(k, 2), q(:, 1) - camPos(k, 1)) - hd + pi, 2 * pi) - pi) <= deg2rad(fov / 2);
camTrk = path(inCone(path, near), :);  camTrk = camTrk(1:3:end, :);
% fence segment (display), coloured by zone of the nearest zone piece
[~, nn] = min((((F.lon - Zs.G.lon0) * Zs.G.kx / 1e3)' - (Zs.Z.piece.x / 1e3)) .^ 2 + (((F.lat - Zs.G.lat0) * Zs.G.ky / 1e3)' - (Zs.Z.piece.y / 1e3)) .^ 2, [], 1);
zone = Zs.Z.zone(Zs.Z.piece.cell(nn));
%% figure
W = round(cfg.figSizeIn(1) * 96);  Hh = round(cfg.figSizeIn(2) * 96);
fig = figure('Color', 'w', 'Position', [60 40 W Hh], 'Units', 'pixels', 'Visible', 'off');
ax = axes(fig, 'Position', [0.008 0.215 0.640 0.775]);  hold(ax, 'on');
image(ax, [-600 600], [452 -452], img);  set(ax, 'YDir', 'normal');
inw = abs(fx) <= hw * 1.2 & abs(fy) <= hh * 1.2;
for z = 1:3
    m = inw & zone == z;  xs = fx;  ys = fy;  xs(~m) = NaN;  ys(~m) = NaN;
    plot(ax, xs, ys, '-', 'Color', [zc(z, :) 0.35], 'LineWidth', 6);  plot(ax, xs, ys, '-', 'Color', zc(z, :), 'LineWidth', 1.8);
end
% camera cones + cameras
for k = 1:numel(camL)
    a = hd + deg2rad(linspace(-fov / 2, fov / 2, 24));  px = [camPos(k, 1) camPos(k, 1) + R * cos(a)];  py = [camPos(k, 2) camPos(k, 2) + R * sin(a)];
    isN = k == near;  patch(ax, px, py, [0.2 0.55 1], 'FaceAlpha', 0.04 + 0.24 * isN, 'EdgeColor', [0.2 0.55 1], 'LineWidth', 0.4 + 1.0 * isN);
end
scatter(ax, camPos(:, 1), camPos(:, 2), 30, 's', 'MarkerFaceColor', [0.2 0.55 1], 'MarkerEdgeColor', 'w', 'LineWidth', 0.8);
% trajectory
plot(ax, path(:, 1), path(:, 2), '-', 'Color', [1 1 1 0.9], 'LineWidth', 2.4);  plot(ax, path(:, 1), path(:, 2), '--', 'Color', [0.85 0.1 0.1], 'LineWidth', 1.2);
scatter(ax, path(1, 1), path(1, 2), 40, 'o', 'MarkerFaceColor', [0.85 0.1 0.1], 'MarkerEdgeColor', 'w');
quiver(ax, path(end - 6, 1), path(end - 6, 2), path(end, 1) - path(end - 6, 1), path(end, 2) - path(end - 6, 2), 0, 'Color', [0.85 0.1 0.1], 'LineWidth', 1.4, 'MaxHeadSize', 3);
% camera track
scatter(ax, camTrk(:, 1), camTrk(:, 2), 22, '^', 'MarkerFaceColor', [0.1 0.4 0.95], 'MarkerEdgeColor', 'w', 'LineWidth', 0.6);
% DAS track + ellipse (1 sigma), rotated to the fence
plot(ax, das(:, 1), das(:, 2), '-', 'Color', [0.95 0.55 0.0], 'LineWidth', 1.0);
scatter(ax, das(:, 1), das(:, 2), 26, 'o', 'MarkerFaceColor', [0.95 0.55 0.0], 'MarkerEdgeColor', 'w', 'LineWidth', 0.6);
ph = linspace(0, 2 * pi, 60);  last = das(end, :);
ex = last(1) + sa * cos(ph) * t(1) + sc_ * sin(ph) * o(1);  ey = last(2) + sa * cos(ph) * t(2) + sc_ * sin(ph) * o(2);
patch(ax, ex, ey, [0.95 0.55 0], 'FaceAlpha', 0.25, 'EdgeColor', [0.95 0.55 0], 'LineWidth', 1.4);
% link line between the last DAS point and the camera-track end nearest to it
[~, kc] = min(hypot(camTrk(:, 1) - last(1), camTrk(:, 2) - last(2)));
plot(ax, [last(1) camTrk(kc, 1)], [last(2) camTrk(kc, 2)], '-', 'Color', [0.1 0.7 0.3], 'LineWidth', 2.2);
text(ax, last(1) + 6 * t(1) - 14 * o(1), last(2) + 6 * t(2) - 14 * o(2), {'DAS track \leftrightarrow camera track', 'linked (same person)'}, 'Color', [0.05 0.45 0.2], 'FontName', fn.name, 'FontSize', 7.5, 'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8], 'Margin', 2, 'VerticalAlignment', 'top');
text(ax, path(1, 1), path(1, 2) + 8, 'trajectory', 'Color', 'w', 'FontName', fn.name, 'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
axis(ax, 'equal');  xlim(ax, [-hw hw]);  ylim(ax, [-hh hh]);  axis(ax, 'off');
% scale bar (50 m) + north arrow
plot(ax, [-hw + 10, -hw + 30], [-hh + 9 -hh + 9], '-', 'Color', 'w', 'LineWidth', 4);  plot(ax, [-hw + 10, -hw + 30], [-hh + 9 -hh + 9], '-', 'Color', 'k', 'LineWidth', 1.6);
text(ax, -hw + 20, -hh + 17, '20 m', 'Color', 'w', 'FontName', fn.name, 'FontSize', 7, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
rectangle(ax, 'Position', [-hw -hh 2 * hw 2 * hh], 'EdgeColor', th.frame, 'LineWidth', 0.8);
%% overview inset (plant, interrogator, channels, zoom window)
ov = axes(fig, 'Position', [0.665 0.515 0.325 0.475]);  hold(ov, 'on');
rx = fx / 1e3;  ry = fy / 1e3;  zz = [zone; zone(1)];
for z = 1:3, xs = [rx; rx(1)]; ys = [ry; ry(1)]; m = zz == z; m2 = m(1:end-1) & m(2:end); xs([false; ~m2]) = NaN; ys([false; ~m2]) = NaN; plot(ov, xs, ys, '-', 'Color', zc(z, :), 'LineWidth', 1.8); end
bx = toX(F.building(2)) / 1e3;  by = toY(F.building(1)) / 1e3;
scatter(ov, bx, by, 46, 's', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', th.frame, 'LineWidth', 1.2);
for k = 1:2, i2 = F.ch(k).idx;  quiver(ov, rx(i2(30)), ry(i2(30)), rx(i2(34)) - rx(i2(30)), ry(i2(34)) - ry(i2(30)), 0, 'Color', th.frame, 'LineWidth', 1.1, 'MaxHeadSize', 6); end
rectangle(ov, 'Position', [-hw / 1e3, -hh / 1e3, 2 * hw / 1e3, 2 * hh / 1e3] + [-0.06 -0.06 0.12 0.12], 'EdgeColor', [0.85 0.1 0.1], 'LineWidth', 1.4);
scatter(ov, 0, 0, 22, 'o', 'MarkerFaceColor', [0.85 0.1 0.1], 'MarkerEdgeColor', 'w');
text(ov, bx + 0.25, by + 0.35, 'control room /\newlineinterrogator', 'FontName', fn.name, 'FontSize', 6.5, 'Color', th.iuLbl, 'FontWeight', 'bold');
text(ov, 0.25, -0.5, 'intrusion', 'FontName', fn.name, 'FontSize', 6.5, 'Color', th.intLbl, 'FontWeight', 'bold');
axis(ov, 'equal');  axis(ov, 'off');  xlim(ov, [min(rx) - 0.4, max(rx) + 0.4]);  ylim(ov, [min(ry) - 0.4, max(ry) + 0.4]);
annotation(fig, 'rectangle', [0.665 0.515 0.325 0.475], 'Color', th.panelEdge, 'LineWidth', 0.6);
text(ov, 0.02, 0.03, sprintf('Fibre path to alarm: %.1f km', Sc.intr.z_m / 1e3), 'Units', 'normalized', 'FontName', fn.name, 'FontSize', 6.2, 'Color', th.muted);
%% right text block: key + quoted number
ka = axes(fig, 'Position', [0.665 0.215 0.325 0.29]);  hold(ka, 'on');  axis(ka, 'off');  xlim(ka, [0 1]);  ylim(ka, [0 1]);
rectangle(ka, 'Position', [0 0 1 1], 'FaceColor', th.panel, 'EdgeColor', th.panelEdge, 'LineWidth', 0.6);
items = {[0.85 0.1 0.1], 'o', 'Intruder trajectory (simulated)'; [0.95 0.55 0], 'o', 'DAS track + 1-sigma localisation ellipse'; [0.1 0.4 0.95], '^', 'Camera track (nearest fixed camera, in its FOV cone)'; [0.2 0.55 1], 's', 'Fixed cameras, 20 m spacing (illustrative)'};
for k = 1:4, yy = 0.90 - (k - 1) * 0.13;  scatter(ka, 0.06, yy, 22, items{k, 2}, 'MarkerFaceColor', items{k, 1}, 'MarkerEdgeColor', 'w');  text(ka, 0.12, yy, items{k, 3}, 'FontName', fn.name, 'FontSize', 6.3, 'Color', th.text, 'VerticalAlignment', 'middle'); end
text(ka, 0.04, 0.30, sprintf('SIMULATED (full-das re-ID grid): link accuracy %.4f,\nlink rate %.4f (fixed cameras, 20 m spacing,\n1.0 m position error, 0.2 s clock offset)', acc, rate), 'FontName', fn.name, 'FontSize', 6.2, 'Color', th.text, 'VerticalAlignment', 'middle', 'FontWeight', 'bold');
text(ka, 0.04, 0.06, 'Ellipse sizes, camera range (55 m) and path are illustrative [ASSUMED].', 'FontName', fn.name, 'FontSize', 5.4, 'Color', th.muted, 'VerticalAlignment', 'middle');
%% step strip
ar = char(8594);  steps = {'1  Approach', '2  Fence crossing', '3  DAS detects: human', '4  Camera track linked', '5  ALARM in control room'};
sa_ = axes(fig, 'Position', [0.008 0.012 0.982 0.185]);  hold(sa_, 'on');  axis(sa_, 'off');  xlim(sa_, [0 5]);  ylim(sa_, [0 1]);
sub_ = {'intruder outside the fence', 'vibration on the fibre', 'localised, with error ellipse', 'DAS + camera track: same person', 'alarm + camera view to operator'};
for k = 1:5
    rectangle(sa_, 'Position', [k - 1 + 0.03, 0.05, 0.94, 0.9], 'FaceColor', th.panel, 'EdgeColor', th.panelEdge, 'Curvature', 0.08, 'LineWidth', 0.6);
    text(sa_, k - 0.5, 0.66, steps{k}, 'HorizontalAlignment', 'center', 'FontName', fn.name, 'FontSize', 8, 'FontWeight', 'bold', 'Color', th.frame);
    text(sa_, k - 0.5, 0.30, sub_{k}, 'HorizontalAlignment', 'center', 'FontName', fn.name, 'FontSize', 6.2, 'Color', th.text);
    if k < 5, text(sa_, k, 0.5, ar, 'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', th.muted, 'FontName', fn.name); end
end
annotation(fig, 'textbox', [0.008 0.0 0.98 0.025], 'String', cfg.imageryCredit, 'EdgeColor', 'none', 'FontName', fn.name, 'FontSize', 5.2, 'Color', th.credit, 'VerticalAlignment', 'bottom', 'Margin', 0);
fig.Position = [60 40 W Hh];  drawnow;  pause(0.3);
if ~exist(c.figDir, 'dir'), mkdir(c.figDir); end
png = fullfile(c.figDir, 'intruder_map.png');
exportgraphics(fig, png, 'Resolution', dpi, 'BackgroundColor', 'w');
if dpi >= 300, exportgraphics(fig, strrep(png, '.png', '.pdf'), 'ContentType', 'image', 'Resolution', dpi, 'BackgroundColor', 'w'); end
close(fig);
fprintf('intruder_map: person_link_acc %.4f, person_link_rate %.4f (reid_grid.csv row), cameras %d, near cam %d -> %s\n', acc, rate, numel(camL), near, png);
end
