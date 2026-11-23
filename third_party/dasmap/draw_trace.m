function h = draw_trace(fig, pos, scene)
% DRAW_TRACE  DAS trace panel: output of the phi-OTDR simulation (DAS-Simulation branch febus-a1neo, cropped to one FEBUS channel). The mapping to the map is
% stated under the plot: walking = map intruder, vehicle = map vehicle; digging and the calibration sine are simulated only
% (not placed on the map, neutral colour). Returns the plot axes and marker handles of the walking / vehicle peaks.
cfg = scene.cfg;  th = scene.th;  sim = scene.sim;  fn = cfg.font;  ks = cfg.uiScale;
bg = panel_axes(fig, pos, th, ks);
hin = pos(4) * cfg.figSizeIn(2) / ks;                             % design inches
u = ks / cfg.figSizeIn(2);                                         % normalised height of one design inch
text(bg, 0.05, 1 - 0.12 / hin, [char(966) '-OTDR SIMULATION'], 'Color', th.muted, 'FontName', fn.name, 'FontSize', fn.title.size, ...
    'FontWeight', 'bold', 'VerticalAlignment', 'middle');
axBottom = pos(2) + 0.68 * u;   axTop = pos(2) + pos(4) - 0.30 * u;
ax = axes(fig, 'Position', [pos(1) + 0.15 * pos(3), axBottom, 0.80 * pos(3), axTop - axBottom], 'Color', 'none');
ax.Tag = 'panel';   hold(ax, 'on');
Lch = scene.events.secLen;   kk = sim.z / 1e3 <= Lch;   z = sim.z(kk) / 1e3;   a = sim.a(kk);          % one channel
patch(ax, [z; flipud(z)], [a; zeros(size(a))], th.trace, 'FaceAlpha', 0.16, 'EdgeColor', 'none');
plot(ax, z, a, '-', 'Color', th.trace, 'LineWidth', 0.5 * ks);
yline(ax, sim.thr, '--', 'Color', th.thr, 'LineWidth', 0.7 * ks);
text(ax, 0.2, sim.thr + 0.4, 'threshold', 'Color', th.thr, 'FontName', fn.name, 'FontSize', fn.note.size, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
ymax = max(a) * 1.30;   h = struct('ax', ax);
for i = 1:numel(sim.events)
    ev = sim.events(i);
    switch ev.type
        case "walk",    col = th.intLbl;   lab = "walking";
        case "vehicle", col = th.aniLbl;   lab = "vehicle";
        case "dig",     col = th.muted;    lab = "digging";
        otherwise,      col = th.muted;    lab = "calibration";
    end
    hm = plot(ax, ev.z0 / 1e3, ev.peak_nm, 'o', 'MarkerSize', 2.8 * ks, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'none');
    if ev.type == "walk", h.walk = [ev.z0 / 1e3, ev.peak_nm]; elseif ev.type == "vehicle", h.veh = [ev.z0 / 1e3, ev.peak_nm]; end
    text(ax, ev.z0 / 1e3, ev.peak_nm + 0.025 * ymax, lab, 'Color', col, 'FontName', fn.name, 'FontSize', fn.note.size, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    clear hm
end
xlim(ax, [0 Lch]);   ylim(ax, [0 ymax]);   xticks(ax, 0:5:floor(Lch));   yticks(ax, 0:10:20);
ax.FontName = fn.name;   ax.FontSize = fn.note.size;   ax.XColor = th.muted;   ax.YColor = th.muted;
ax.LineWidth = 0.5 * ks;   ax.TickDir = 'out';   ax.Box = 'off';   ax.YGrid = 'on';   ax.GridColor = th.grid;   ax.GridAlpha = 0.6;
xlabel(ax, 'Distance (km)', 'Color', th.muted, 'FontSize', fn.note.size);
ylabel(ax, 'Activity (nm rms)', 'Color', th.muted, 'FontSize', fn.note.size);
% mapping rows (design inches from the panel bottom)
ar = char(8594);   dg = char(8224);
rows = {th.intLbl,  ['walking = map intruder: detected ' ar ' human ' ar ' ALARM ' dg];
        th.aniLbl,  ['vehicle = map vehicle: detected ' ar ' on road ' ar ' logged ' dg];
        th.muted,   'digging, calibration: simulated only, not on the map'};
for k = 1:3
    yy = 0.33 - (k - 1) * 0.12;
    plot(bg, 0.06, yy / hin, 'o', 'MarkerSize', 3 * ks, 'MarkerFaceColor', rows{k, 1}, 'MarkerEdgeColor', 'none');
    text(bg, 0.10, yy / hin, rows{k, 2}, 'Color', th.text, 'FontName', fn.name, 'FontSize', fn.note.size, 'VerticalAlignment', 'middle');
end
end
