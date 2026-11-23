function [png, scene] = render_figure(scene, themeName)
% RENDER_FIGURE  Compose the report/presentation figure from ONE scene in the requested theme.
% Layout: wide oblique 3D map across the top; below it a row with status panel, Mashaer inset and DAS trace; legend and
% credit at the bottom. The inset shows EXACTLY the lat/lon rectangle scene.inset (orthographic, same azimuth as the main
% view). That rectangle is drawn on the map as a flat frame at constant height; two connectors join the frame's lower
% corners to the inset's upper corners. Returns the scene with the cached inset calibration.
cfg = scene.cfg;  scene.th = get_theme(cfg, themeName);  th = scene.th;  T = scene.T;  I = scene.inset;
Lc = cfg.layout;  lw = cfg.gfx;
W = round(cfg.figSizeIn(1) * 96);   H = round(cfg.figSizeIn(2) * 96);
fig = figure('Color', th.bg, 'Position', [60 40 W H], 'Units', 'pixels', 'Visible', 'off');

% ---------------- main 3D view ----------------
ax = axes(fig, 'Position', Lc.main);   hold(ax, 'on');
draw_terrain(ax, scene, 'satellite', false);
draw_risk(ax, scene);
draw_fibre(ax, scene, lw);
draw_infra(ax, scene, lw);
draw_assets(ax, scene, lw);
draw_events(ax, scene, lw);
cx = [I.x(1) I.x(2) I.x(2) I.x(1)];   cy = [I.y(1) I.y(1) I.y(2) I.y(2)];           % SW SE NE NW
patch(ax, 'XData', cx, 'YData', cy, 'ZData', I.zf * ones(1, 4), 'FaceColor', th.frame, 'FaceAlpha', 0.10, ...
    'EdgeColor', th.frame, 'LineWidth', 0.8);                                         % flat frame, constant height
axis(ax, 'off');   ax.DataAspectRatio = [1 1 1];   ax.Clipping = 'off';
F = scene.fibre;   mg = 2.5;                                                          % the perimeter plus a 2.5 km margin of terrain
ax.XLim = [min(F.x) - mg, max(F.x) + mg];   ax.YLim = [min(F.y) - mg, max(F.y) + mg];   ax.ZLim = [0 8];
set_camera(ax, main_target(scene), cfg.camera);
drawnow;
draw_labels(ax, scene, "Masjid al-Haram", true);
halo_text(ax, mean(I.x), I.y(1) - 1.6, I.zf, 'Mashaer', cfg.font.asset, th.lblText, scene);

% ---------------- inset calibration (once) and layout ----------------
colW = round(Lc.insetW * W);
if ~isfield(scene, 'insetCal'), scene.insetCal = calibrate_inset(scene, colW); end
cal = scene.insetCal;
colHn = cal.hpx / H;                                                    % inset height, normalised
px = find_markers(fig, ax, [cx' cy' I.zf * ones(4, 1)], W, H);          % frame corners on screen (SW SE NE NW)
insetPos  = [Lc.insetX, Lc.rowY + (Lc.rowH - colHn) / 2, Lc.insetW, colHn];
statusPos = [Lc.statusX(1), Lc.rowY, Lc.statusX(2), Lc.rowH];
tracePos  = [Lc.traceX(1),  Lc.rowY, Lc.traceX(2),  Lc.rowH];

% ---------------- inset image + frame + connectors ----------------
img = render_inset(scene, cal);
axi = axes(fig, 'Position', insetPos);   image(axi, img);
axis(axi, 'off');   axi.DataAspectRatioMode = 'auto';
annotation(fig, 'rectangle', insetPos, 'Color', th.frame, 'LineWidth', 0.8);
sw = px(1, :);   se = px(2, :);                                         % nearest (lower) corners of the frame
top = insetPos(2) + insetPos(4);
annotation(fig, 'line', [sw(1) / W, insetPos(1)],                [1 - sw(2) / H, top], 'Color', th.frame, 'LineWidth', 0.7);
annotation(fig, 'line', [se(1) / W, insetPos(1) + insetPos(3)],  [1 - se(2) / H, top], 'Color', th.frame, 'LineWidth', 0.7);

% ---------------- panels, legend, credit ----------------
draw_status(fig, statusPos, scene);
draw_trace(fig, tracePos, scene);
draw_legend(fig, Lc.legend, scene);
annotation(fig, 'textbox', Lc.credit, 'String', cfg.imageryCredit, 'EdgeColor', 'none', 'Color', th.credit, ...
    'FontName', cfg.font.name, 'FontSize', cfg.font.note.size, 'VerticalAlignment', 'bottom', 'Margin', 0);

oa = axes(fig, 'Position', [0 0 1 1], 'Color', 'none');   hold(oa, 'on');   oa.XLim = [0 1];   oa.YLim = [0 1];   axis(oa, 'off');
north_arrow(oa, [0.03, Lc.main(2) + 0.40 * Lc.main(4)], 0.10, th.text, th.bg, cfg);                      % main map (on the page)
north_arrow(oa, [insetPos(1) + insetPos(3) - 0.022, insetPos(2) + insetPos(4) - 0.115], 0.075, [1 1 1], [0.06 0.08 0.11], cfg);   % inset (on imagery)

drawnow;   pause(0.5);
png = fullfile(cfg.outDir, sprintf('digital_twin_%s.png', th.name));
exportgraphics(fig, png, 'Resolution', cfg.exportDpi, 'BackgroundColor', th.bg, 'Padding', 'figure');
pdf = strrep(png, '.png', '.pdf');
exportgraphics(fig, pdf, 'ContentType', 'image', 'Resolution', cfg.exportDpi, 'BackgroundColor', th.bg, 'Padding', 'figure');
close(fig);
fprintf('Saved %s (+ .pdf)\n', png);
end

% =====================================================================================
function set_inset_camera(a, scene, va)
% Orthographic oblique view from due south (same azimuth as the main view), centred on the frame.
I = scene.inset;   el = scene.cfg.insetEl;   az = scene.cfg.camera.az;
tgt = [mean(I.x), mean(I.y), I.zf];
a.Projection = 'orthographic';
a.CameraTarget = tgt;
a.CameraPosition = tgt + 120 * [sind(az) * cosd(el), cosd(az) * cosd(el), sind(el)];
a.CameraUpVector = [0 0 1];
a.CameraViewAngle = va;
end

function cal = calibrate_inset(scene, colW)
% Find the view angle at which the rectangle is exactly colW px wide, and where its corners fall in the render
% figure (measured from uniquely coloured markers in the real axes; the same camera is used for the final render).
cfg = scene.cfg;  T = scene.T;  I = scene.inset;
colHest = colW / I.aspect;   Rw = round(colW + 120);   Rh = round(colHest + 120);
f = figure('Color', 'k', 'Position', [60 40 Rw Rh], 'Units', 'pixels', 'Visible', 'off');
a = axes(f, 'Position', [0 0 1 1]);   hold(a, 'on');
m = T.base;                                                                  % surrogate terrain (no texture needed)
surface(a, flipud(m.X), flipud(m.Y), flipud(m.Z), 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none');
axis(a, 'off');   a.DataAspectRatio = [1 1 1];   a.Clipping = 'off';
a.XLim = [min(m.X(:)) max(m.X(:))];   a.YLim = [min(m.Y(:)) max(m.Y(:))];   a.ZLim = [0 8];
pts = [[I.x(1) I.x(2) I.x(2) I.x(1)]', [I.y(1) I.y(1) I.y(2) I.y(2)]', I.zf * ones(4, 1)];   % SW SE NE NW
va = 2450 / colW;   hist = zeros(0, 2);     % ortho scale is ~ 1/view angle: width[px] x angle[deg] ~ 2450 (measured)
for it = 1:6
    set_inset_camera(a, scene, va);
    p = find_markers(f, a, pts, Rw, Rh);
    wpx = mean(p([2 3], 1)) - mean(p([1 4], 1));
    hist(end+1, :) = [va wpx]; %#ok<AGROW>
    if abs(wpx / colW - 1) < 0.004, break; end
    if size(hist, 1) > 1
        q = -log(hist(end, 2) / hist(end-1, 2)) / log(hist(end, 1) / hist(end-1, 1));
        if ~isfinite(q) || abs(q) < 0.2, q = 1; end
    else, q = 1;
    end
    va = va * (wpx / colW)^(1 / q);
end
close(f);
cal.va = va;   cal.Rw = Rw;   cal.Rh = Rh;
cal.x0 = mean(p([1 4], 1));   cal.x1 = mean(p([2 3], 1));                  % west / east edge [px]
cal.y0 = mean(p([3 4], 2));   cal.y1 = mean(p([1 2], 2));                  % north / south edge [px]
cal.wpx = cal.x1 - cal.x0;   cal.hpx = cal.y1 - cal.y0;
cal.kmPerPx = (I.x(2) - I.x(1)) / cal.wpx;
fprintf('Inset calibration: view angle %.2f deg (%d iterations), rectangle %.0f x %.0f px\n', va, it, cal.wpx, cal.hpx);
if abs(cal.wpx / colW - 1) > 0.02, warning('INSET:CAL', 'Inset width %.0f px differs from target %d px.', cal.wpx, colW); end
end

function img = render_inset(scene, cal)
% Render the Mashaer scene with the calibrated orthographic camera and crop it to the rectangle.
cfg = scene.cfg;  th = scene.th;  lw = cfg.gfx;  T = scene.T;
scene.orthoKmPerPx = cal.kmPerPx;
f = figure('Color', th.bg, 'Position', [60 40 cal.Rw cal.Rh], 'Units', 'pixels', 'Visible', 'off');
a = axes(f, 'Position', [0 0 1 1]);   hold(a, 'on');
draw_terrain(a, scene, 'satellite', true);
draw_risk(a, scene);
draw_fibre(a, scene, lw);
draw_infra(a, scene, lw);
draw_assets(a, scene, lw);
draw_events(a, scene, lw);
axis(a, 'off');   a.DataAspectRatio = [1 1 1];   a.Clipping = 'off';
a.XLim = [min(T.base.X(:)) max(T.base.X(:))];   a.YLim = [min(T.base.Y(:)) max(T.base.Y(:))];   a.ZLim = [0 8];
set_inset_camera(a, scene, cal.va);
drawnow;
draw_labels(a, scene, cfg.insetSites, false, cfg.insetLabelScale);
drawnow;
tmp = [tempname '.png'];
exportgraphics(f, tmp, 'Resolution', cfg.exportDpi, 'BackgroundColor', th.bg, 'Padding', 'figure');
close(f);
im = imread(tmp);   delete(tmp);
s = size(im, 2) / cal.Rw;
img = im(round(cal.y0 * s) + 1 : round(cal.y1 * s), round(cal.x0 * s) + 1 : round(cal.x1 * s), :);
end

function px = find_markers(fig, ax, pts, W, H)
% Plant uniquely coloured markers at the 3D points in the REAL axes, export once at 1x, locate them, remove them.
h = gobjects(size(pts, 1), 1);
for i = 1:size(pts, 1)
    h(i) = scatter3(ax, pts(i,1), pts(i,2), pts(i,3), 300, 'o', 'filled', 'MarkerFaceColor', [1 10 * i / 255 0], 'MarkerEdgeColor', 'none');
end
drawnow;
tmp = [tempname '.png'];
exportgraphics(fig, tmp, 'Resolution', 96, 'Padding', 'figure');
im = double(imread(tmp));   delete(tmp);   delete(h);
sc = size(im, 2) / W;
px = nan(size(pts, 1), 2);
for i = 1:size(pts, 1)
    m = abs(im(:,:,1) - 255) <= 10 & abs(im(:,:,2) - 10 * i) <= 3 & im(:,:,3) <= 10;
    [r, c] = find(m);
    if ~isempty(r), px(i, :) = [mean(c), mean(r)] / sc; end
end
if any(isnan(px(:))), error('Marker(s) %s not found (hidden or off screen).', mat2str(find(any(isnan(px), 2))')); end
end
