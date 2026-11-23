function main_interactive(varargin)
% MAIN_INTERACTIVE  Interactive, animated version of the digital-twin figure (same scene and config as main_static).
%
%   main_interactive                         open the interactive window
%   main_interactive('video', 'out/x.mp4')   render the animation off-screen to a 1920x1080 MP4 (no window)
%   main_interactive('theme', 'light')       start in the light theme (default 'dark')
%
% Window controls: Map (Satellite / Dark), Theme (Dark / Light), Zoom to Mashaer (or click the Mashaer frame / the terrain
% inside it), Reset view, Pause / Play, Restart.  Animation (loops): light pulses travel along the fibre from each interrogator,
% UAVs hover, an intruder walks to the perimeter, the fibre turns red at detection, the label builds up "detected -> human ->
% ALARM", the response lines appear and the nearest UAV and patrol move in; then a vehicle drives along its road, is detected,
% classified and logged (no alarm).  Classification and alarm belong to the PROPOSED system and are not simulated.
%
% Name-value options: 'size' [w h] (default [1600 900]), 'fps' (24), 'texScale' (0.5), 'meshStride' (2),
%                     'testTimes' (times in s -> PNG snapshots out/_anim_t*.png, for checking), 'duration' (video length, 33).
here = fileparts(mfilename('fullpath'));
addpath(here, fullfile(here, 'data'));
ip = inputParser;
addParameter(ip, 'video', '');       addParameter(ip, 'theme', 'dark');   addParameter(ip, 'size', [1600 900]);
addParameter(ip, 'fps', 24);         addParameter(ip, 'texScale', 0.5);   addParameter(ip, 'meshStride', 2);
addParameter(ip, 'testTimes', []);   addParameter(ip, 'testZoom', 0);   addParameter(ip, 'duration', 33);    addParameter(ip, 'maxFrames', inf);
parse(ip, varargin{:});   o = ip.Results;
videoMode = ~isempty(o.video);   testMode = ~isempty(o.testTimes);   offscreen = videoMode || testMode;

% ---------------------------------------------------------------- scene (identical to the static figure)
cfg0 = config(o.theme);
if ~exist(cfg0.outDir, 'dir'), mkdir(cfg0.outDir); end
fetch_boundary_osm();  build_perimeter();  prepare_terrain();  fetch_roads_osm();
if ~isfile(cfg0.simFile), error('Run data/import_das_sim.m first (phi-OTDR simulator output, see data/SOURCES.md).'); end
scene = build_scene(cfg0);

ks = o.size(1) / 768;                                                % scale of fonts / markers vs. the 8 x 5 in static design
cfg = cfg0;   cfg.uiScale = ks;   cfg.figSizeIn = [8 4.5] * ks;   cfg.gfx = cfg0.gfx * ks;
for nm = ["site" "asset" "panel" "title" "note"], cfg.font.(nm).size = cfg0.font.(nm).size * ks; end
scene.cfg = cfg;   scene.th = get_theme(cfg, o.theme);   scene.anim = true;   scene.meshStride = o.meshStride;
th = scene.th;   c = cfg.col;   lw = cfg.gfx;   T = scene.T;   F = scene.fibre;   E = scene.events;   A = scene.assets;
I = scene.inset;   sim = scene.sim;   U = scene.uav;   nIU = numel(F.iuIdx);

% ---------------------------------------------------------------- timeline [s]
tInt0 = 1.0;   tInt1 = 7.0;                    % intruder appears and walks to the perimeter
tDet = 7.0;   tHum = 8.2;   tAlm = 9.4;        % detected -> human -> ALARM
tResp = 10.2;   tMove0 = 11.7;   tMove1 = 15.7;% response lines grow, then the nearest UAV and patrol move in
tVeh0 = 16.5;   tVeh1 = 22.0;                  % vehicle drives along its road (detected when it passes the fibre)
Tev = 27.0;                                    % end of the event cycle; the loop restarts here
vp = 9;   spacing = cfg.pulseSpacingKm;        % pulse speed [km/s, display] and spacing

% ---------------------------------------------------------------- figure and layout
vis = 'on';   if offscreen, vis = 'off'; end
fig = figure('Name', 'DAS digital twin - interactive', 'NumberTitle', 'off', 'Color', th.bg, 'Units', 'pixels', ...
    'Position', [30 30 o.size], 'MenuBar', 'none', 'ToolBar', 'none', 'Visible', vis, 'CloseRequestFcn', @onClose);
Lmain = [0 0.395 1 0.555];   rowY = 0.075;   rowH = 0.308;
statusPos = [0.006 rowY 0.268 rowH];   tracePos = [0.284 rowY 0.358 rowH];   legendPos = [0.652 rowY 0.342 rowH];
ax = axes(fig, 'Position', Lmain);   hold(ax, 'on');

% ---------------------------------------------------------------- terrain (satellite / dark textures, decimated for speed)
tex = struct('sat', {{}}, 'dark', {{}});   hT = gobjects(1, 2);
meshes = {T.base, T.mashaer};   lifts = [0 0.004];
for mi = 1:2
    mm = meshes{mi};   st = o.meshStride;
    ri = unique([1:st:size(mm.X, 1), size(mm.X, 1)]);   ci = unique([1:st:size(mm.X, 2), size(mm.X, 2)]);
    img = imread(mm.tex);   if o.texScale < 1, img = imresize(img, o.texScale); end
    g = rgb2gray(img);   tex.sat{mi} = img;   tex.dark{mi} = cat(3, g * 0.30, g * 0.46, g * 0.58);
    hT(mi) = surface(ax, flipud(mm.X(ri, ci)), flipud(mm.Y(ri, ci)), flipud(mm.Z(ri, ci)) + lifts(mi), tex.sat{mi}, ...
        'FaceColor', 'texturemap', 'EdgeColor', 'none', 'FaceLighting', 'none');
end
mapMode = 'sat';

% ---------------------------------------------------------------- static layers (shared with the static figure)
draw_risk(ax, scene);
hf = draw_fibre(ax, scene, lw);
draw_infra(ax, scene, lw);
draw_assets(ax, scene, lw);                                           % interrogators only (UAVs are animated below)
cx = [I.x(1) I.x(2) I.x(2) I.x(1)];   cy = [I.y(1) I.y(1) I.y(2) I.y(2)];
hFrame = patch(ax, 'XData', cx, 'YData', cy, 'ZData', I.zf * ones(1, 4), 'FaceColor', th.frame, 'FaceAlpha', 0.10, ...
    'EdgeColor', th.frame, 'LineWidth', 0.8 * ks, 'Tag', 'frame');
axis(ax, 'off');   ax.DataAspectRatio = [1 1 1];   ax.Clipping = 'off';
mg = 2.5;   ax.XLim = [min(F.x) - mg, max(F.x) + mg];   ax.YLim = [min(F.y) - mg, max(F.y) + mg];   ax.ZLim = [0 8];
camMain = cfg.camera;   camMain.dist = 0.84 * cfg.camera.dist;      % the interactive map area is wider than the static one
set_camera(ax, main_target(scene), camMain);
posA = ax.CameraPosition;   tgtA = ax.CameraTarget;   vaA = ax.CameraViewAngle;
drawnow;
draw_labels(ax, scene, string(scene.sites.name), true);
halo_text(ax, mean(I.x), I.y(1) - 1.6, I.zf, 'Mashaer', cfg.font.asset, th.lblText, scene, 'mashaerTag', 'lbl_text');
% the four Mashaer site labels only appear when zoomed in
mashSites = ["Jamarat" "Mina" "Muzdalifah" "Arafat"];
hMashLbl = gobjects(0);
for nm = mashSites, hMashLbl = [hMashLbl; findobj(ax, '-regexp', 'Tag', ['^(halo:|top:)?site:' char(nm) '$'])]; end %#ok<AGROW>
set(hMashLbl, 'Visible', 'off');
% event labels start empty and are built up by the animation
hLblInt = [findobj(ax, 'Tag', 'top:intruderLabel'); findobj(ax, 'Tag', 'halo:intruderLabel')];
hLblVeh = [findobj(ax, 'Tag', 'top:vehicleLabel');  findobj(ax, 'Tag', 'halo:vehicleLabel')];
hLdrInt = findobj(ax, 'Tag', 'leader:intruderLabel');   hLdrVeh = findobj(ax, 'Tag', 'leader:vehicleLabel');
set([hLblInt; hLblVeh], 'String', '');   set([hLdrInt; hLdrVeh], 'Visible', 'off');

% ---------------------------------------------------------------- animated objects
an = struct();
% light pulses: three layers per interrogator (long faint tail, mid, short bright head)
plen = [4.5 2.7 1.1];   pcol = {[c.cyan 0.22], [c.cyan 0.55], [1 1 1 1]};   pw = [9 5.5 2.6] * lw;
an.pulse = gobjects(F.nSeg, 3);                                       % one pulse train per channel (segment)
for k = 1:F.nSeg, for q = 1:3, an.pulse(k, q) = plot3(ax, NaN, NaN, NaN, '-', 'Color', pcol{q}, 'LineWidth', pw(q)); end, end
nn_ = numel(F.s_km) - 1;                                              % the last fibre sample repeats the first (closed ring)
sE = [F.s_km(1:nn_); F.s_km(1:nn_) + F.L_km];   xE = [F.x(1:nn_); F.x(1:nn_)];   yE = [F.y(1:nn_); F.y(1:nn_)];   zE = [F.z(1:nn_); F.z(1:nn_)] + 0.02;
% UAVs: rigid icon + cone in an hgtransform, moved every frame
an.uav = gobjects(1, numel(U));   uavStart = zeros(numel(U), 3);
for k = 1:numel(U)
    g = hgtransform('Parent', ax);   an.uav(k) = g;   arm = 0.85;   ang = [pi/4 3*pi/4 5*pi/4 7*pi/4];
    ring = linspace(0, 2*pi, 48)';   alt = U(k).z - U(k).gz;
    V = [0 0 0; cfg.uavConeR * cos(ring), cfg.uavConeR * sin(ring), -alt * ones(48, 1)];   Fc = [ones(47, 1), (2:48)', (3:49)'];
    patch('Parent', g, 'Faces', Fc, 'Vertices', V, 'FaceColor', c.cyan, 'FaceAlpha', 0.20, 'EdgeColor', 'none');
    plot3(V(2:end, 1), V(2:end, 2), V(2:end, 3), '-', 'Parent', g, 'Color', [c.cyan 0.9], 'LineWidth', 1.5 * lw);
    for q = 1:6:48, plot3([0 V(q+1, 1)], [0 V(q+1, 2)], [0 V(q+1, 3)], '-', 'Parent', g, 'Color', [c.cyan 0.45], 'LineWidth', 0.9 * lw); end
    for q = 1:4
        plot3([0 arm * cos(ang(q))], [0 arm * sin(ang(q))], [0 0], '-', 'Parent', g, 'Color', c.uav, 'LineWidth', 2.6 * lw);
        scatter3(arm * cos(ang(q)), arm * sin(ang(q)), 0, 16 * ks^2, 'o', 'Parent', g, 'MarkerFaceColor', c.uav, 'MarkerEdgeColor', c.cyan, 'LineWidth', 0.6 * ks);
    end
    scatter3(0, 0, 0, 18 * ks^2, 'o', 'Parent', g, 'MarkerFaceColor', c.cyan, 'MarkerEdgeColor', 'none');
    uavStart(k, :) = [U(k).x U(k).y U(k).z];
end
respIdx = find([U.responding], 1);
% breach zone (radial red patch), ripples, track, intruder marker
[bx, by] = meshgrid(linspace(-2.8, 2.8, 56));   rr = hypot(bx, by);
Xb = E.cross(1) + bx;   Yb = E.cross(2) + by;   Zb = T.heightXY(Xb, Yb) + 0.045;
alphaBreach = 0.55 * max(1 - rr / 2.8, 0).^1.4;
an.breach = surface(ax, Xb, Yb, Zb, cat(3, c.red(1) * ones(size(rr)), c.red(2) * ones(size(rr)), c.red(3) * ones(size(rr))), ...
    'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceAlpha', 'interp', 'AlphaData', 0 * alphaBreach, 'AlphaDataMapping', 'none');
an.trail = plot3(ax, NaN, NaN, NaN, ':', 'Color', [1 0.50 0.45 0.98], 'LineWidth', 2.2 * lw);
an.trailGlow = plot3(ax, NaN, NaN, NaN, '-', 'Color', [c.red 0.28], 'LineWidth', 6 * lw);
an.rip = gobjects(1, 3);   for q = 1:3, an.rip(q) = plot3(ax, NaN, NaN, NaN, '-', 'Color', [c.red 0], 'LineWidth', 1.6 * lw); end
an.mkGlow = scatter3(ax, NaN, NaN, NaN, 150 * ks^2, 'o', 'MarkerFaceColor', c.red, 'MarkerFaceAlpha', 0.25, 'MarkerEdgeColor', 'none');
an.mk = scatter3(ax, NaN, NaN, NaN, 32 * ks^2, 'o', 'MarkerFaceColor', c.red, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.9 * ks);
% response lines and the moving patrol
an.uavLine = plot3(ax, NaN, NaN, NaN, '--', 'Color', [1 1 1 0.95], 'LineWidth', 1.8 * lw);
an.patLine = plot3(ax, NaN, NaN, NaN, '--', 'Color', [c.patrol 0.98], 'LineWidth', 1.8 * lw);
pat0 = A.patrol(A.patrolNearest, :);
an.patMk = scatter3(ax, pat0(1), pat0(2), pat0(3) + 0.10, 40 * ks^2, 's', 'MarkerFaceColor', c.patrol, 'MarkerEdgeColor', [0.1 0.12 0.15], 'LineWidth', 0.7 * ks);
% vehicle: the road it is on (highlighted) and the moving marker
for k = 1:numel(E.roadLines)
    r = E.roadLines{k};   plot3(ax, r(:, 1), r(:, 2), r(:, 3), '-', 'Color', [c.yellow 0.95], 'LineWidth', 2.0 * lw, 'Tag', 'road');
end
an.vGlow = scatter3(ax, NaN, NaN, NaN, 110 * ks^2, 'o', 'MarkerFaceColor', c.yellow, 'MarkerFaceAlpha', 0.22, 'MarkerEdgeColor', 'none');
an.vMk = scatter3(ax, NaN, NaN, NaN, 20 * ks^2, 'o', 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', [1 1 1], 'LineWidth', 0.7 * ks);
% road path of the vehicle: the polyline through the vehicle point, +-1.8 km along the road
path = vehicle_path(E);
[~, kPass] = min(hypot(path(:, 1) - E.vehicle(1), path(:, 2) - E.vehicle(2)));
cum = [0; cumsum(hypot(diff(path(:, 1)), diff(path(:, 2))))];   fPass = cum(kPass) / cum(end);
tPass = tVeh0 + fPass * (tVeh1 - tVeh0);
% energy along the fibre (colouring) = quiet level + the two simulated peaks, each with its own time envelope
sk = F.s_km(:);   Lk = F.L_km;   ref = scene.energyRef_nm;
gI = exp(-0.5 * (min(abs(sk - E.s_int), Lk - abs(sk - E.s_int)) / 0.8).^2);
gV = exp(-0.5 * (min(abs(sk - E.s_veh), Lk - abs(sk - E.s_veh)) / 0.8).^2);
eBase = sim.median / ref;   pkI = E.peak_int_nm / ref;   pkV = E.peak_veh_nm / ref;

% ---------------------------------------------------------------- panels, legend, credit, north arrows, stage caption
oa = axes(fig, 'Position', [0 0 1 1], 'Color', 'none', 'HitTest', 'off', 'PickableParts', 'none');   hold(oa, 'on');
oa.XLim = [0 1];   oa.YLim = [0 1];   axis(oa, 'off');
hStage = text(oa, 0.99, 0.925, '', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'FontName', cfg.font.name, ...
    'FontSize', 9.5 * ks, 'FontWeight', 'bold', 'Color', th.text);
hCredit = annotation(fig, 'textbox', [0.006 0.004 0.988 0.062], 'String', cfg.imageryCredit, 'EdgeColor', 'none', ...
    'FontName', cfg.font.name, 'FontSize', cfg.font.note.size, 'VerticalAlignment', 'bottom', 'Margin', 0, 'Color', th.credit);
hTrace = struct();   hRing = gobjects(1, 2);
build_panels();
hBar = gobjects(0);
if ~offscreen, build_controls(); end

% ---------------------------------------------------------------- state
paused = false;   tAnim = 0;   clk = tic;   tLast = 0;   camTarget = 0;   camFrac = 0;   stageInt = -1;   stageVeh = -1;
camZoom = zoom_camera();
hFrame.ButtonDownFcn = @(~, ~) zoom_to(1);
hT(1).ButtonDownFcn = @surfClick;   hT(2).ButtonDownFcn = @surfClick;
tmr = [];

anim_update(0);   cam_apply(0);   drawnow;

% ================================================================ run modes
if testMode
    for tTest = o.testTimes
        anim_update(tTest);   cam_apply(o.testZoom);
        exportgraphics(fig, fullfile(cfg.outDir, sprintf('_anim_t%05.1f.png', tTest)), 'Resolution', 96, 'Padding', 'figure');
    end
    close(fig, 'force');   return
elseif videoMode
    nF = min(round(o.duration * o.fps), o.maxFrames);
    [vdir, ~, ~] = fileparts(o.video);   if ~isempty(vdir) && ~exist(vdir, 'dir'), mkdir(vdir); end
    vw = VideoWriter(o.video, 'MPEG-4');   vw.FrameRate = o.fps;   vw.Quality = 95;   open(vw);
    ts = tic;
    for f = 0:nF - 1
        t = f / o.fps;
        anim_update(t);
        camFrac = video_cam(t);   cam_apply(camFrac);
        drawnow;
        fr = print(fig, '-RGBImage', '-r0');
        if size(fr, 1) ~= o.size(2) || size(fr, 2) ~= o.size(1), fr = imresize(fr, [o.size(2) o.size(1)]); end
        writeVideo(vw, fr);
        if mod(f, 24) == 0, fprintf('video: frame %d / %d  (%.1f s elapsed)\n', f, nF, toc(ts)); end
    end
    close(vw);   close(fig, 'force');
    fprintf('Saved %s (%d x %d, %d fps, %.1f s)\n', o.video, o.size(1), o.size(2), o.fps, nF / o.fps);
    return
end
tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.04, 'BusyMode', 'drop', 'TimerFcn', @(~, ~) tick());
start(tmr);

% ================================================================ nested functions
    function tick()
        if ~isvalid(fig), return; end
        now_ = toc(clk);   dt = now_ - tLast;   tLast = now_;
        if ~paused, tAnim = mod(tAnim + dt, Tev); end
        anim_update(tAnim);
        step = 1 / 1.2 * dt;                                           % camera moves at 1/1.2 per second
        if camFrac < camTarget, camFrac = min(camFrac + step, camTarget); elseif camFrac > camTarget, camFrac = max(camFrac - step, camTarget); end
        cam_apply(camFrac);
        drawnow limitrate;
    end

    function anim_update(t)
        tE = min(t, Tev);
        ss = @(x) (min(max(x, 0), 1)).^2 .* (3 - 2 * min(max(x, 0), 1));
        % ---- pulses (always running)
        phase = mod(vp * t, spacing);
        for k = 1:F.nSeg
            s0 = F.s_km(F.segNearIdx(k)) + (F.segDir(k) < 0) * F.L_km;   heads = phase:spacing:(F.segLenKm(k) - 0.2);
            for q = 1:3
                XS = [];  YS = [];  ZS = [];
                for d = heads
                    a = max(d - plen(q), 0);   sg = s0 + F.segDir(k) * linspace(a, d, 10);
                    XS = [XS, interp1(sE, xE, sg), NaN];  YS = [YS, interp1(sE, yE, sg), NaN];  ZS = [ZS, interp1(sE, zE, sg), NaN]; %#ok<AGROW>
                end
                set(an.pulse(k, q), 'XData', XS, 'YData', YS, 'ZData', ZS);
            end
        end
        % ---- UAVs hovering; the nearest one flies to the intruder along the response arc
        rU = ss((tE - tMove0) / (tMove1 - tMove0));
        for k = 1:numel(U)
            bob = 0.10 * sin(2 * pi * 0.45 * t + k);   yaw = 0.35 * sin(2 * pi * 0.2 * t + k);
            p = uavStart(k, :);
            if k == respIdx
                tgt = [E.cross(1) E.cross(2) E.intruder(3) + 0.3];
                p = uavStart(k, :) + (tgt - uavStart(k, :)) * rU;   p(3) = p(3) - 0.25 * sin(pi * rU);
            end
            an.uav(k).Matrix = makehgtform('translate', [p(1) p(2) p(3) + bob], 'zrotate', yaw);
        end
        % ---- intruder walking to the perimeter
        u = ss((tE - tInt0) / (tInt1 - tInt0));   tp = linspace(0, 1, numel(E.trackX));
        showInt = tE >= tInt0;
        if showInt
            xi = interp1(tp, E.trackX, u);   yi = interp1(tp, E.trackY, u);   zi = interp1(tp, E.trackZ, u);
            n = max(2, round(u * numel(tp)));
            set(an.trail, 'XData', E.trackX(1:n), 'YData', E.trackY(1:n), 'ZData', E.trackZ(1:n));
            set(an.trailGlow, 'XData', E.trackX(1:n), 'YData', E.trackY(1:n), 'ZData', E.trackZ(1:n));
            set(an.mkGlow, 'XData', xi, 'YData', yi, 'ZData', zi + 0.06);   set(an.mk, 'XData', xi, 'YData', yi, 'ZData', zi + 0.06);
        else
            set([an.trail an.trailGlow], 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            set([an.mkGlow an.mk], 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end
        a1 = ss((tE - tDet) / 0.8);                                    % detection: fibre turns red
        an.breach.AlphaData = alphaBreach * a1;
        for q = 1:3                                                    % alarm ripples
            rad = mod((tE - tDet) * 1.2 + (q - 1) * 0.8, 2.4);   ang = linspace(0, 2 * pi, 80)';
            xr = E.cross(1) + rad * cos(ang);   yr = E.cross(2) + rad * sin(ang);
            set(an.rip(q), 'XData', xr, 'YData', yr, 'ZData', T.heightXY(xr, yr) + 0.05, 'Color', [c.red a1 * (1 - rad / 2.4) * 0.9]);
        end
        % ---- response lines grow, then the UAV and the patrol move along them
        gR = ss((tE - tResp) / 1.5);   tq = linspace(0, max(gR, 1e-3), 40)';
        if gR > 0
            u0 = uavStart(respIdx, :);
            set(an.uavLine, 'XData', u0(1) + (E.cross(1) - u0(1)) * tq, 'YData', u0(2) + (E.cross(2) - u0(2)) * tq, ...
                'ZData', u0(3) + (E.intruder(3) + 0.3 - u0(3)) * tq - 0.25 * sin(pi * tq));
            px_ = pat0(1) + (E.cross(1) - pat0(1)) * tq;   py_ = pat0(2) + (E.cross(2) - pat0(2)) * tq;
            set(an.patLine, 'XData', px_, 'YData', py_, 'ZData', T.heightXY(px_, py_) + 0.07);
        else
            set([an.uavLine an.patLine], 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end
        xp = pat0(1) + (E.cross(1) - pat0(1)) * rU;   yp = pat0(2) + (E.cross(2) - pat0(2)) * rU;
        set(an.patMk, 'XData', xp, 'YData', yp, 'ZData', T.heightXY(xp, yp) + 0.10);
        % ---- vehicle on its road
        vf = min(max((tE - tVeh0) / (tVeh1 - tVeh0), 0), 1);   showVeh = tE >= tVeh0 && tE <= tVeh1 + 2;
        if showVeh
            pv = interp1(cum / cum(end), path, vf);
            set(an.vGlow, 'XData', pv(1), 'YData', pv(2), 'ZData', pv(3) + 0.06);   set(an.vMk, 'XData', pv(1), 'YData', pv(2), 'ZData', pv(3) + 0.06);
            dV = hypot(pv(1) - E.vehicleFibre(1), pv(2) - E.vehicleFibre(2));
            a2 = ss(1 - dV / 1.6);
        else
            set([an.vGlow an.vMk], 'XData', NaN, 'YData', NaN, 'ZData', NaN);   a2 = 0;
        end
        % ---- fibre colour and hot-spot glow
        e = eBase + (pkI - eBase) * a1 * gI + (pkV - eBase) * a2 * gV;   e = min(max(e, 0), 1);
        hf.core.CData = [e; e(1)];
        set(hf.hot(1).glow, 'Color', [c.red 0.32 * a1]);   set(hf.hot(1).core, 'Color', [c.red 0.95 * a1]);
        set(hf.hot(2).glow, 'Color', [c.red 0.32 * a2]);   set(hf.hot(2).core, 'Color', [c.red 0.95 * a2]);
        % ---- label stages (strings change only when the stage changes)
        ar = char(8594);
        sI = (tE >= tDet) + (tE >= tHum) + (tE >= tAlm);
        if sI ~= stageInt
            strs = {'', 'detected', ['detected ' ar ' human'], ['detected ' ar ' human ' ar ' ALARM']};
            set(hLblInt, 'String', strs{sI + 1});   set(hLdrInt, 'Visible', onoff(sI > 0));   stageInt = sI;
            if isfield(hTrace, 'ringW'), set(hRing(1), 'Visible', onoff(sI > 0)); end
        end
        sV = (tE >= tPass) + (tE >= tPass + 1.2) + (tE >= tPass + 2.4);
        if sV ~= stageVeh
            strs = {'', 'detected', ['detected ' ar ' vehicle on road'], ['detected ' ar ' vehicle on road ' ar ' logged']};
            set(hLblVeh, 'String', strs{sV + 1});   set(hLdrVeh, 'Visible', onoff(sV > 0));   stageVeh = sV;
            if isfield(hTrace, 'ringV'), set(hRing(2), 'Visible', onoff(sV > 0)); end
        end
        % ---- stage caption (in step with the label stages above)
        if sV > 0
            capsV = {'', ['Vehicle detected: activity above the threshold'], ['Proposed AI classifier ' char(8224) ': vehicle on road'], ...
                     ['Logged, no alarm ' char(8224) ': vehicle on road']};
            cap = capsV{sV + 1};
        elseif tE >= tPass - 2.5 && tE >= tVeh0
            cap = 'A vehicle drives along a road next to the fibre';
        elseif sI == 3 && tE >= tResp, cap = ['ALARM: nearest UAV and patrol dispatched ' char(8224)];
        elseif sI == 3, cap = ['Proposed AI classifier ' char(8224) ': human ' ar ' ALARM'];
        elseif sI == 2, cap = ['Proposed AI classifier ' char(8224) ': human'];
        elseif sI == 1, cap = 'Event detected: activity above the threshold';
        elseif tE >= tInt0, cap = 'An intruder approaches the perimeter';
        else, cap = 'Monitoring: light pulses probe the fibre, UAVs and patrols stand by';
        end
        hStage.String = cap;
    end

    function s = onoff(b), if b, s = 'on'; else, s = 'off'; end, end

    function p = vehicle_path(Ev)
        % polyline of the vehicle's road: +-1.8 km (along the road) around the vehicle point, with height
        best = inf;   bk = 1;   bi = 1;
        for kk = 1:numel(Ev.roadLines)
            rl = Ev.roadLines{kk};   d = hypot(rl(:, 1) - Ev.vehicle(1), rl(:, 2) - Ev.vehicle(2));
            [dm, im] = min(d);   if dm < best, best = dm; bk = kk; bi = im; end
        end
        rl = Ev.roadLines{bk};   n = size(rl, 1);   ok = ~isnan(rl(:, 1));
        i0 = bi;   acc = 0;   while i0 > 1 && ok(i0 - 1) && acc < 1.8, acc = acc + hypot(rl(i0, 1) - rl(i0 - 1, 1), rl(i0, 2) - rl(i0 - 1, 2)); i0 = i0 - 1; end
        i1 = bi;   acc = 0;   while i1 < n && ok(i1 + 1) && acc < 1.8, acc = acc + hypot(rl(i1 + 1, 1) - rl(i1, 1), rl(i1 + 1, 2) - rl(i1, 2)); i1 = i1 + 1; end
        p = rl(i0:i1, :);
    end

    function cam = zoom_camera()
        tg = [mean(I.x), mean(I.y), 1.2];   el = cfg.insetEl;   dist = 24;
        cam.tgt = tg;   cam.pos = tg + dist * [0, -cosd(el), sind(el)];   cam.va = 30;
    end

    function cam_apply(fr)
        s = fr^2 * (3 - 2 * fr);
        ax.CameraPosition = posA + (camZoom.pos - posA) * s;
        ax.CameraTarget = tgtA + (camZoom.tgt - tgtA) * s;
        ax.CameraViewAngle = vaA + (camZoom.va - vaA) * s;
        showMash = s > 0.5;
        set(hMashLbl, 'Visible', onoff(showMash));
        set(hFrame, 'Visible', onoff(~showMash));
        set(findobj(ax, 'Tag', 'top:mashaerTag'), 'Visible', onoff(~showMash));
        set(findobj(ax, 'Tag', 'halo:mashaerTag'), 'Visible', onoff(~showMash));
    end

    function fr = video_cam(t)
        % scripted camera for the video: zoom into the Mashaer after the event cycle, hold, return
        z0 = Tev + 0.5;   z1 = z0 + 2.0;   h1 = z1 + 2.0;   r1 = h1 + 2.0;
        if t < z0, fr = 0; elseif t < z1, fr = (t - z0) / 2; elseif t < h1, fr = 1; elseif t < r1, fr = 1 - (t - h1) / 2; else, fr = 0; end
    end

    function zoom_to(target)
        camTarget = target;
    end

    function surfClick(~, evt)
        if isprop(evt, 'IntersectionPoint')
            pt = evt.IntersectionPoint;
            if pt(1) >= I.x(1) && pt(1) <= I.x(2) && pt(2) >= I.y(1) && pt(2) <= I.y(2), camTarget = 1; end
        end
    end

    function build_panels()
        draw_status(fig, statusPos, scene);
        hTrace = draw_trace(fig, tracePos, scene);
        draw_legend(fig, legendPos, scene, 2, true);
        for q = 1:2 * isfield(hTrace, 'walk')   % rings that mark simulated events on the trace (none on the analytic trace)
            if q == 1, pk = hTrace.walk; col = th.intLbl; else, pk = hTrace.veh; col = th.aniLbl; end
            hRing(q) = plot(hTrace.ax, pk(1), pk(2), 'o', 'MarkerSize', 7.5 * ks, 'MarkerFaceColor', 'none', 'MarkerEdgeColor', col, ...
                'LineWidth', 1.2 * ks, 'Visible', 'off');
        end
        if isfield(hTrace, 'walk'), hTrace.ringW = hRing(1);   hTrace.ringV = hRing(2); end
        delete(findobj(fig, 'Tag', 'north'));
        north_arrow(oa, [0.03 0.50], 0.11, th.text, th.bg, cfg);
    end

    function build_controls()
        hBar = uipanel(fig, 'Units', 'normalized', 'Position', [0 0.95 1 0.05], 'BorderType', 'none', 'BackgroundColor', th.panel);
        mk = @(sty, str, pos, cb) uicontrol(hBar, 'Style', sty, 'String', str, 'Units', 'normalized', 'Position', pos, ...
            'FontSize', 10, 'Callback', cb, 'BackgroundColor', th.panel, 'ForegroundColor', th.text);
        mk('text', 'Map', [0.008 0.15 0.035 0.6], []);
        uicontrol(hBar, 'Style', 'popupmenu', 'String', {'Satellite', 'Dark'}, 'Units', 'normalized', 'Position', [0.045 0.15 0.085 0.7], ...
            'FontSize', 10, 'Callback', @(s, ~) set_map(s.Value));
        mk('text', 'Theme', [0.14 0.15 0.045 0.6], []);
        v = 1 + strcmp(th.name, 'light');
        uicontrol(hBar, 'Style', 'popupmenu', 'String', {'Dark', 'Light'}, 'Units', 'normalized', 'Position', [0.187 0.15 0.075 0.7], ...
            'FontSize', 10, 'Value', v, 'Callback', @(s, ~) set_theme(lower(s.String{s.Value})));
        mk('pushbutton', 'Zoom to Mashaer', [0.28 0.12 0.12 0.76], @(~, ~) zoom_to(1));
        mk('pushbutton', 'Reset view', [0.405 0.12 0.09 0.76], @(~, ~) zoom_to(0));
        hPause = mk('pushbutton', 'Pause', [0.5 0.12 0.07 0.76], []);
        hPause.Callback = @(~, ~) toggle_pause(hPause);
        mk('pushbutton', 'Restart', [0.575 0.12 0.07 0.76], @(~, ~) restart());
    end

    function toggle_pause(h)
        paused = ~paused;   if paused, h.String = 'Play'; else, h.String = 'Pause'; end
    end

    function restart()
        tAnim = 0;   stageInt = -1;   stageVeh = -1;
    end

    function set_map(v)
        if v == 1, mapMode = 'sat'; else, mapMode = 'dark'; end
        for mi = 1:2, hT(mi).CData = tex.(mapMode){mi}; end
        drawnow;
    end

    function set_theme(name)
        scene.th = get_theme(cfg, name);   th = scene.th;
        fig.Color = th.bg;
        delete(findobj(fig, 'Tag', 'panel'));   build_panels();
        hStage.Color = th.text;   hCredit.Color = th.credit;
        hFrame.FaceColor = th.frame;   hFrame.EdgeColor = th.frame;
        set(findobj(ax, 'Tag', 'iu'), 'MarkerEdgeColor', th.frame);
        set(findobj(ax, '-regexp', 'Tag', '^halo:'), 'Color', th.lblHalo);
        tops = findobj(ax, '-regexp', 'Tag', '^top:');
        for q = 1:numel(tops)
            switch tops(q).UserData
                case 'lbl_text', tops(q).Color = th.lblText;
                case 'lbl_iu',   tops(q).Color = th.iuLbl;
                case 'lbl_int',  tops(q).Color = th.intLbl;
                case 'lbl_veh',  tops(q).Color = th.aniLbl;
            end
        end
        set(findobj(ax, '-regexp', 'Tag', '^leader:'), 'Color', [th.lblText 0.6]);
        set(findobj(ax, '-regexp', 'Tag', '^site:', '-and', 'Type', 'line'), 'Color', [th.lblText 0.6]);
        set(findobj(ax, '-regexp', 'Tag', '^site:', '-and', 'Type', 'scatter'), 'MarkerFaceColor', th.lblText, 'MarkerEdgeColor', th.lblHalo);
        if ~isempty(hBar) && isvalid(hBar)
            hBar.BackgroundColor = th.panel;
            set(findobj(hBar, 'Type', 'uicontrol'), 'BackgroundColor', th.panel, 'ForegroundColor', th.text);
        end
        stageInt = -1;   stageVeh = -1;   drawnow;
    end

    function onClose(~, ~)
        try, if ~isempty(tmr) && isvalid(tmr), stop(tmr); delete(tmr); end, catch, end
        delete(fig);
    end
end
