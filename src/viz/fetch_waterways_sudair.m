function n = fetch_waterways_sudair()
% FETCH_WATERWAYS_SUDAIR  OSM waterway=* inside the terrain AOI (same Overpass method as the roads). Returns the number of features.
% Nothing is drawn unless OSM has features; wadis are never invented.
c = sasg_config();  M = load(fullfile(c.dataDir, 'dem', 'tex_meta.mat'));  b = M.meta.base;
f = fullfile(c.dataDir, 'osm_waterways.json');
if ~isfile(f)
    bb = sprintf('%.4f,%.4f,%.4f,%.4f', b.lat(1), b.lon(1), b.lat(2), b.lon(2));
    q = ['[out:json][timeout:90];(way["waterway"](' bb ');relation["waterway"](' bb '););out geom tags;'];
    opts = weboptions('Timeout', 200, 'UserAgent', c.UA, 'HeaderFields', {'Accept' '*/*'}, 'ContentType', 'text');
    for a = 1:6
        try
            txt = webwrite('https://overpass-api.de/api/interpreter', 'data', q, opts);
            if startsWith(strtrim(txt), '{'), break; end
        catch
        end
        if a == 6, error('Overpass unavailable for the waterway query'); end
        pause(10 * a);
    end
    fid = fopen(f, 'w', 'n', 'UTF-8');  fwrite(fid, txt);  fclose(fid);
end
d = jsondecode(fileread(f, 'Encoding', 'UTF-8'));  n = numel(d.elements);
fprintf('OSM waterways in the AOI: %d\n', n);
end
