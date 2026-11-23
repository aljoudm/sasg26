function draw_risk(ax, scene)
% DRAW_RISK  Weak-coverage heat map (semi-transparent) draped on the terrain. Computed, not drawn by hand
% (compute_risk.m): slope + not seen by any CCTV + distance to roads, within a corridor around the fibre.
T = scene.T;  R = scene.risk;  cfg = scene.cfg;  c = cfg.col;  m = T.base;
if isfield(scene, 'meshStride') && scene.meshStride > 1
    ri = unique([1:scene.meshStride:size(m.X, 1), size(m.X, 1)]);   ci = unique([1:scene.meshStride:size(m.X, 2), size(m.X, 2)]);
    m.X = m.X(ri, ci);   m.Y = m.Y(ri, ci);   m.Z = m.Z(ri, ci);
end
LAT = T.toLat(m.Y);   LON = T.toLon(m.X);
rk = R.at(LAT, LON);   al = R.alphaAt(LAT, LON);
t = min(max((rk - cfg.riskShowFrom) / (1 - cfg.riskShowFrom), 0), 1);
CD = cat(3, c.riskLo(1) + (c.riskHi(1) - c.riskLo(1)) * t, ...
            c.riskLo(2) + (c.riskHi(2) - c.riskLo(2)) * t, ...
            c.riskLo(3) + (c.riskHi(3) - c.riskLo(3)) * t);
surface(ax, flipud(m.X), flipud(m.Y), flipud(m.Z) + 0.05, flipud(CD), 'FaceColor', 'interp', 'EdgeColor', 'none', ...
    'FaceAlpha', 'interp', 'AlphaData', flipud(al), 'AlphaDataMapping', 'none');
end
