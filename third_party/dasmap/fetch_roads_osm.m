function matPath = fetch_roads_osm(force)
% FETCH_ROADS_OSM  Major roads (motorway..tertiary + links) inside the terrain AOI from OpenStreetMap.
% Used for: road-distance layer of the risk score, road entry points (checkpoints), patrol positions.
if nargin < 1, force = false; end
cfg = config();
matPath = fullfile(cfg.dataDir, 'roads_osm.mat');
if isfile(matPath) && ~force, return; end
jsonPath = fullfile(cfg.dataDir, 'roads_osm.json');
if ~isfile(jsonPath)
    M = load(cfg.texMeta);  b = M.meta.base;
    bbox = sprintf('%.4f,%.4f,%.4f,%.4f', b.lat(1), b.lon(1), b.lat(2), b.lon(2));
    q = ['[out:json][timeout:180];way["highway"~"^(motorway|trunk|primary|secondary|tertiary|motorway_link|trunk_link|primary_link)$"](' ...
         bbox ');out geom tags;'];
    opts = weboptions('Timeout', 200, 'UserAgent', 'capstone-das-figure/0.1', 'HeaderFields', {'Accept' '*/*'}, 'ContentType', 'text');
    for attempt = 1:4
        try
            txt = webwrite('https://overpass-api.de/api/interpreter', 'data', q, opts);  break;
        catch err
            if attempt == 4, rethrow(err); end
            pause(15);
        end
    end
    fid = fopen(jsonPath, 'w', 'n', 'UTF-8');  fwrite(fid, txt);  fclose(fid);
end
d = jsondecode(fileread(jsonPath, 'Encoding', 'UTF-8'));
els = d.elements;  roads = struct('class', {}, 'lat', {}, 'lon', {});
for k = 1:numel(els)
    if iscell(els), e = els{k}; else, e = els(k); end
    if ~isfield(e, 'geometry'), continue; end
    roads(end+1) = struct('class', string(e.tags.highway), 'lat', [e.geometry.lat]', 'lon', [e.geometry.lon]'); %#ok<AGROW>
end
save(matPath, 'roads');
fprintf('Roads: %d ways (%s)\n', numel(roads), strjoin(unique([roads.class]), ','));
end
