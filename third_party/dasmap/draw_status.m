function draw_status(fig, pos, scene)
% DRAW_STATUS  Status panel. Facts, computed design values and proposed (dagger) scenario values are kept apart.
% Rows are placed in DESIGN inches (the 8 x 5 in static size); cfg.uiScale (ks) scales fonts, markers and line widths with the window.
cfg = scene.cfg;  th = scene.th;  F = scene.fibre;  A = scene.assets;  c = cfg.col;  fn = cfg.font;  ks = cfg.uiScale;
ax = panel_axes(fig, pos, th, ks);
hin = pos(4) * cfg.figSizeIn(2) / ks;                              % panel height in design inches
Y = @(inch) 1 - inch / hin;
txt = @(x, inch, s, col, st, ha) text(ax, x, Y(inch), s, 'Color', col, 'FontName', fn.name, 'FontSize', st.size, ...
    'FontWeight', st.weight, 'HorizontalAlignment', ha, 'VerticalAlignment', 'middle');
bold = struct('size', fn.panel.size, 'weight', 'bold');
txt(0.05, 0.12, 'STATUS', th.muted, fn.title, 'left');
rows = {'Fibre length',          sprintf('%.1f km', F.L_km);
        'Interrogator units',    sprintf('%d', F.N_IU);
        'Sensing points',        thousands(F.N_sensing);
        ['CCTV / UAV / patrols ' char(8224)], sprintf('%d / %d / %d', numel(A.cctv), numel(scene.uav), size(A.patrol, 1));
        'Hajj 2026 pilgrims',    thousands(cfg.hajjPilgrims2026)};
y = 0.30;
for i = 1:size(rows, 1)
    txt(0.05, y, rows{i,1}, th.muted, fn.panel, 'left');
    txt(0.95, y, rows{i,2}, th.text, bold, 'right');
    y = y + 0.135;
end
plot(ax, [0.05 0.95], Y([y - 0.07 y - 0.07]), '-', 'Color', th.panelEdge, 'LineWidth', 0.5 * ks);
y = y + 0.03;
plot(ax, 0.075, Y(y), 'o', 'MarkerSize', 3.8 * ks, 'MarkerFaceColor', c.red, 'MarkerEdgeColor', 'none');
rowFont = fn.panel;   if ks > 1.2, rowFont.size = 0.86 * rowFont.size; end     % wider interactive window: keep the row clear of ALARM
txt(0.12, y, ['Intruder: detected ' char(8594) ' human ' char(8224)], th.text, rowFont, 'left');
txt(0.95, y, 'ALARM', th.intLbl, bold, 'right');
y = y + 0.135;
plot(ax, 0.075, Y(y), 'o', 'MarkerSize', 3.8 * ks, 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', 'none');
txt(0.12, y, ['Vehicle on road ' char(8224)], th.text, fn.panel, 'left');
txt(0.95, y, 'LOGGED', th.aniLbl, bold, 'right');
txt(0.05, hin - 0.085, [char(8224) ' proposed scenario / placement'], th.muted, fn.note, 'left');
end

function s = thousands(n)
s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end
