function draw_labels(ax, scene, siteNames, showAssets, hs)
% DRAW_LABELS  Holy-site names (primary), IU / C2 / event labels (secondary). Halo text, thin leader
% lines, one font family. Call AFTER set_camera so halo offsets match the view.
if nargin < 5, hs = 1; end                    % leader-height scale (shorter leaders in the inset)
cfg = scene.cfg;  th = scene.th;  S = scene.sites;  ks = cfg.uiScale;  F = scene.fibre;  E = scene.events;  A = scene.assets;
for k = 1:height(S)
    if ~ismember(S.name(k), siteNames), continue; end
    z0 = S.z(k) + 0.05;
    ax_ = S.x(k) + S.dx(k);   ay_ = S.y(k) + S.dy(k);   zl = z0 + (3.0 + S.dz(k)) * hs;
    plot3(ax, [S.x(k) ax_], [S.y(k) ay_], [z0 zl], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.5 * ks, 'Tag', ['site:' char(S.name(k))]);
    scatter3(ax, S.x(k), S.y(k), z0, 12 * ks^2, 'o', 'MarkerFaceColor', th.lblText, 'MarkerEdgeColor', th.lblHalo, 'LineWidth', 0.5 * ks, 'Tag', ['site:' char(S.name(k))]);
    halo_text(ax, ax_, ay_, zl + 0.3, char(S.name(k)), cfg.font.site, th.lblText, scene, ['site:' char(S.name(k))], 'lbl_text');
end
if ~showAssets, return; end
for k = 1:numel(F.iuIdx)
    halo_text(ax, F.iuX(k), F.iuY(k), F.iuZ(k) + 2.8, sprintf('IU-%d', k), cfg.font.asset, th.iuLbl, scene, sprintf('iu%d', k), 'lbl_iu');
end
halo_text(ax, A.c2(1), A.c2(2), A.c2(3) + 3.1, 'C2', cfg.font.asset, th.iuLbl, scene, 'c2', 'lbl_iu');
ar = char(8594);
sgn = sign(E.vehicle(1) - E.intruder(1));   if sgn == 0, sgn = 1; end            % labels go to opposite sides
% event labels stacked at different heights (they climb into the empty band above the far edge), thin leaders down to the markers
xl = E.intruder(1) - sgn * 3.0;   zl = E.intruder(3) + 9.0;
plot3(ax, [E.intruder(1) xl], [E.intruder(2) E.intruder(2)], [E.intruder(3) + 0.1 zl - 0.5], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.5 * ks, 'Tag', 'leader:intruderLabel');
halo_text(ax, xl, E.intruder(2), zl, ['detected ' ar ' human ' ar ' ALARM'], cfg.font.asset, th.intLbl, scene, 'intruderLabel', 'lbl_int');
xv = E.vehicle(1) + sgn * 4.2;   zv = E.vehicle(3) + 6.6;
plot3(ax, [E.vehicle(1) xv], [E.vehicle(2) E.vehicle(2)], [E.vehicle(3) + 0.1 zv - 0.5], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.5 * ks, 'Tag', 'leader:vehicleLabel');
halo_text(ax, xv, E.vehicle(2), zv, ['detected ' ar ' vehicle on road ' ar ' logged'], cfg.font.asset, th.aniLbl, scene, 'vehicleLabel', 'lbl_veh');
sMid = mod(E.secS0 + E.secDir * E.secLen / 2, F.L_km);                               % middle of the simulated section
xm = interp1(F.s_km, F.x, sMid, 'linear', 'extrap');   ym = interp1(F.s_km, F.y, sMid, 'linear', 'extrap');   zm = interp1(F.s_km, F.z, sMid, 'linear', 'extrap');
zs = zm + 1.6;
plot3(ax, [xm xm - 4.0], [ym ym], [zm + 0.1 zs - 0.5], '-', 'Color', [th.lblText 0.6], 'LineWidth', 0.5 * ks, 'Tag', 'leader:secLabel');
halo_text(ax, xm - 4.0, ym, zs, sprintf('simulated section (%.1f km)', E.secLen), cfg.font.asset, th.lblText, scene, 'secLabel', 'lbl_text');
end
