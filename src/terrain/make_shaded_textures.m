function tcfg = make_shaded_textures(force)
% MAKE_SHADED_TEXTURES  Display-only relief for the flat Sudair site (Stage E restyle). Real data only:
%   * hi-res Esri imagery of the plant (2x2 export tiles, ~2 m/px) -> data/dem/tex_plant_hr.jpg
%   * hillshade from the real Copernicus DEM (dem_aoi.mat), low sun, multiplied into the Esri texture (blend weight w)
%   * subtle atmospheric haze toward the far (north) edge, away from the plant
% Writes data/dem/shaded_base.jpg and shaded_plant.jpg and returns the terrain cfg pointing at them (VERT_EXAG from sasg_viz_params).
if nargin < 1, force = false; end
c = sasg_config();  vp = sasg_viz_params();
tcfg = prepare_terrain_sudair();
M = load(tcfg.texMeta);  meta = M.meta;
hr = fullfile(c.dataDir, 'dem', 'tex_plant_hr.jpg');
sb = fullfile(c.dataDir, 'dem', 'shaded_base.jpg');  sp = fullfile(c.dataDir, 'dem', 'shaded_plant.jpg');
tcfg.VERT_EXAG = vp.VERT_EXAG;
if isfile(sb) && isfile(sp) && ~force, tcfg.texBase = sb;  tcfg.texMashaer = sp;  return; end
%% hi-res plant imagery (2 m/px; Esri refuses finer than ~1.1 m/px in this area)
d = meta.mashaer;  ky = 111195;  kx = ky * cosd(mean(d.lat));
if ~isfile(hr) || force
    wM = diff(d.lon) * kx;  hM = diff(d.lat) * ky;  nx = ceil(wM / 4700);  ny = ceil(hM / 4700);
    lons = linspace(d.lon(1), d.lon(2), nx + 1);  lats = linspace(d.lat(2), d.lat(1), ny + 1);   % north first
    rows = cell(ny, 1);
    for r = 1:ny
        cols = cell(1, nx);
        for q = 1:nx
            px = round((lons(q + 1) - lons(q)) * kx / vp.imgMperPx);  py = round(px * (lats(r) - lats(r + 1)) / (lons(q + 1) - lons(q)));   % square pixels in DEGREES (the export's rule); a metric aspect makes Esri stretch the extent
            url = sprintf(['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=%.7f,%.7f,%.7f,%.7f&bboxSR=4326&imageSR=4326&size=%d,%d&format=jpg&f=image'], lons(q), lats(r + 1), lons(q + 1), lats(r), px, py);
            tmp = [tempname '.jpg'];
            for a = 1:4, try, websave(tmp, url, weboptions('Timeout', 180, 'UserAgent', c.UA)); break; catch err, pause(5); if a == 4, rethrow(err); end, end, end
            cols{q} = imread(tmp);  delete(tmp);
        end
        h = min(cellfun(@(x) size(x, 1), cols));  cols = cellfun(@(x) x(1:h, :, :), cols, 'UniformOutput', false);  rows{r} = cat(2, cols{:});
    end
    w = min(cellfun(@(x) size(x, 2), rows));  rows = cellfun(@(x) x(:, 1:w, :), rows, 'UniformOutput', false);
    imwrite(cat(1, rows{:}), hr, 'Quality', 88);
end
%% hillshade from the DEM
S = load(tcfg.demMat);  Z = double(S.Z);  lat = S.lat(:);  lon = S.lon(:)';
kxm = ky * cosd(mean(lat));  dxM = abs(lon(2) - lon(1)) * kxm;  dyM = abs(lat(2) - lat(1)) * ky;
Zs = imgaussfilt(Z, vp.dem_smooth_px) * vp.VERT_EXAG;
[gx, gy] = gradient(Zs, dxM, dyM);  gN = -gy;                                   % rows run north -> south
n = cat(3, -gx, -gN, ones(size(gx)));  n = n ./ sqrt(sum(n .^ 2, 3));
az = deg2rad(vp.sun_az);  el = deg2rad(vp.sun_el);  sv = [sin(az) * cos(el), cos(az) * cos(el), sin(el)];
hs = max(n(:, :, 1) * sv(1) + n(:, :, 2) * sv(2) + n(:, :, 3) * sv(3), 0);
f = hs / sin(el);                                                                 % 1 on flat ground
latA = flipud(lat);  fA = flipud(f);                                              % ascending lat for interp
shade = @(img, lo, la) shade_one(img, lo, la, lon, latA, fA, vp, meta.mashaer.lat(2), meta.base.lat(2));
imwrite(shade(imread(tcfg.texBase), meta.base.lon, meta.base.lat), sb, 'Quality', 90);
imwrite(shade(imgaussfilt(imread(hr), vp.plant_blur_px), meta.mashaer.lon, meta.mashaer.lat), sp, 'Quality', 90);
tcfg.texBase = sb;  tcfg.texMashaer = sp;
fprintf('Shaded textures: sun az %g el %g, blend %.2f, VE x%g, haze max %.2f\n', vp.sun_az, vp.sun_el, vp.blend_w, vp.VERT_EXAG, vp.haze_max);
end
function out = shade_one(img, lonL, latL, lon, latA, fA, vp, plantTop, aoiTop)
[h, w, ~] = size(img);
lo = linspace(lonL(1), lonL(2), w);  la = linspace(latL(2), latL(1), h)';          % north first
LAf = interp2(lon, latA, fA, lo, flipud(la), 'cubic', 1);  Fm = flipud(LAf);       % f on the image grid (north first)
Fm = max(min(Fm, 3), 0);
k = 1 + vp.blend_w * (Fm - 1);
t = min(max((la - plantTop) / (aoiTop - plantTop), 0), 1);  hz = vp.haze_max * t .^ 1.5;   % haze only north of the plant
im = double(img) / 255;
im = im .* k;
g = mean(im, 3);  im = im .* (1 - 0.35 * hz) + g .* (0.35 * hz);                   % desaturate far terrain
hc = reshape(vp.haze_col, 1, 1, 3);  im = im .* (1 - hz) + hc .* hz;
out = uint8(min(max(im, 0), 1) * 255);
end
