function draw_terrain(ax, scene, mode, withMashaer)
% DRAW_TERRAIN  Satellite (default) or dark imagery draped on the Copernicus DEM mesh.
% withMashaer: overlay the higher-resolution Mashaer texture on its own (finer) mesh.
if nargin < 3, mode = 'satellite'; end
if nargin < 4, withMashaer = false; end
T = scene.T;
patchSurf(ax, T.base, mode, 0);
if withMashaer, patchSurf(ax, T.mashaer, mode, 0.004); end   % +4 m display lift avoids z-fighting
end

function patchSurf(ax, m, mode, lift)
img = imread(m.tex);
if strcmp(mode, 'dark')
    g = rgb2gray(img);   img = cat(3, g * 0.30, g * 0.46, g * 0.58);
end
% mesh rows are lat-ascending; flip so row 1 = north = image row 1
surface(ax, flipud(m.X), flipud(m.Y), flipud(m.Z) + lift, img, ...
    'FaceColor', 'texturemap', 'EdgeColor', 'none', 'FaceLighting', 'none');
end
