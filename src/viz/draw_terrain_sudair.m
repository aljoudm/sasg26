function draw_terrain_sudair(ax, scene)
% DRAW_TERRAIN_SUDAIR  Adapted from DAS-map draw_terrain.m (a25fd0c): same surfaces (satellite texture draped on the Copernicus DEM mesh,
% base + plant-detail mesh, +0.004 km display lift for the detail), but the hi-res plant texture is blended into the base texture with a
% smooth feathered alpha mask (scene.vp.feather_m) instead of a hard rectangular edge.
T = scene.T;  vp = scene.vp;
surfTex(ax, T.base, 0, []);
m = T.mashaer;  ky = T.ky * 1000;  kx = T.kx * 1000;
wM = diff(m.lon) * kx;  hM = diff(m.lat) * ky;  na = [330 360];
[ci, ri] = meshgrid(linspace(0, wM, na(2)), linspace(0, hM, na(1)));
d = min(min(ci, wM - ci), min(ri, hM - ri)) / vp.feather_m;  d = min(max(d, 0), 1);  a = d .* d .* (3 - 2 * d);      % smoothstep
surfTex(ax, m, 0.004, a);
end
function surfTex(ax, m, lift, alphaMask)
img = imread(m.tex);
if isempty(alphaMask)
    surface(ax, flipud(m.X), flipud(m.Y), flipud(m.Z) + lift, img, 'FaceColor', 'texturemap', 'EdgeColor', 'none', 'FaceLighting', 'none');
else
    surface(ax, flipud(m.X), flipud(m.Y), flipud(m.Z) + lift, img, 'FaceColor', 'texturemap', 'EdgeColor', 'none', 'FaceLighting', 'none', ...
        'FaceAlpha', 'texturemap', 'AlphaData', alphaMask, 'AlphaDataMapping', 'none');
end
end
