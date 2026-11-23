function draw_status_sudair(fig, pos, scene)
% DRAW_STATUS_SUDAIR  ADAPTED COPY of DAS-map draw_status.m (a25fd0c): same panel, fonts, rows and ALARM / LOGGED lines; the rows are
% the Sudair ones (fibre, interrogator, channels, sensing points, cameras). The Makkah "CCTV / UAV / patrols" and "Hajj pilgrims" rows are gone.
cfg = scene.cfg;  th = scene.th;  F = scene.fibre;  c = cfg.col;  fn = cfg.font;  ks = cfg.uiScale;
ax = panel_axes(fig, pos, th, ks);
hin = pos(4) * cfg.figSizeIn(2) / ks;
Y = @(inch) 1 - inch / hin;
txt = @(x, inch, s, col, st, ha) text(ax, x, Y(inch), s, 'Color', col, 'FontName', fn.name, 'FontSize', st.size, ...
    'FontWeight', st.weight, 'HorizontalAlignment', ha, 'VerticalAlignment', 'middle');
bold = struct('size', fn.panel.size, 'weight', 'bold');
txt(0.05, 0.12, 'STATUS', th.muted, fn.title, 'left');
rows = {'Fibre',      sprintf('%.1f km fence + %.2f km lead-in', F.L_km, 2 * F.lead_m / 1e3);
        'Interrogator',      sprintf('%d', F.N_IU);
        'Channels (active / spare)', sprintf('%d / %d', F.N_ch_active, F.N_ch_spare);
        'Sensing points',    regexprep(sprintf('%d', F.N_sensing), '(\d)(?=(\d{3})+$)', '$1,');
        'Cameras',           'none placed'};
y = 0.28;
for i = 1:size(rows, 1)
    txt(0.05, y, rows{i,1}, th.muted, fn.panel, 'left');
    txt(0.97, y, rows{i,2}, th.text, bold, 'right');
    y = y + 0.125;
end
plot(ax, [0.05 0.95], Y([y - 0.065 y - 0.065]), '-', 'Color', th.panelEdge, 'LineWidth', 0.5 * ks);
y = y + 0.03;
plot(ax, 0.075, Y(y), 'o', 'MarkerSize', 3.8 * ks, 'MarkerFaceColor', c.red, 'MarkerEdgeColor', 'none');
txt(0.12, y, ['Intruder: detected ' char(8594) ' human ' char(8224)], th.text, fn.panel, 'left');
txt(0.95, y, 'ALARM', th.intLbl, bold, 'right');
y = y + 0.125;
plot(ax, 0.075, Y(y), 'o', 'MarkerSize', 3.8 * ks, 'MarkerFaceColor', c.yellow, 'MarkerEdgeColor', 'none');
txt(0.12, y, ['Vehicle on road ' char(8224)], th.text, fn.panel, 'left');
txt(0.95, y, 'LOGGED', th.aniLbl, bold, 'right');
txt(0.05, hin - 0.085, [char(8224) ' simulated scenario'], th.muted, fn.note, 'left');
end
