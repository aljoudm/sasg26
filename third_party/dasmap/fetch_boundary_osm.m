function csvPath = fetch_boundary_osm(force)
% FETCH_BOUNDARY_OSM  Get the Haram boundary ring from OpenStreetMap and save as lat/lon CSV.
% Falls back to a clearly labelled PLACEHOLDER (never real data) if the download fails.
if nargin < 1, force = false; end
cfg = config();
csvPath = cfg.boundaryCsv;
jsonPath = fullfile(cfg.dataDir, sprintf('haram_relation_%d.json', cfg.osmRelationId));
if isfile(csvPath) && ~force, return; end

try
    if ~isfile(jsonPath)
        q = sprintf('[out:json][timeout:90];relation(%d);out geom;', cfg.osmRelationId);
        opts = weboptions('Timeout', 120, 'UserAgent', 'capstone-das-figure/0.1', ...
            'HeaderFields', {'Accept' '*/*'}, 'ContentType', 'text');
        txt = webwrite('https://overpass-api.de/api/interpreter', 'data', q, opts);
        fid = fopen(jsonPath, 'w', 'n', 'UTF-8'); fwrite(fid, txt); fclose(fid);
    end
    d = jsondecode(fileread(jsonPath, 'Encoding', 'UTF-8'));
    mem = d.elements(1).members;
    ways = {};
    for k = 1:numel(mem)
        if iscell(mem), m = mem{k}; else, m = mem(k); end   % members differ in fields -> cell
        if strcmp(m.type, 'way') && strcmp(m.role, 'outer')
            ways{end+1} = [[m.geometry.lat]' [m.geometry.lon]']; %#ok<AGROW>
        end
    end
    ring = join_ways(ways);
    writematrix(ring, csvPath);
    fprintf('Boundary: OSM relation %d, %d vertices -> %s\n', cfg.osmRelationId, size(ring,1), csvPath);
catch err
    warning('BOUNDARY:PLACEHOLDER', ...
        ['OSM boundary unavailable (%s). Writing PLACEHOLDER ellipse - NOT the real Haram ' ...
         'boundary. Do not use for the report.'], err.message);
    t = linspace(0, 2*pi, 400)';
    ring = [21.4225 + 0.25*sin(t), 39.8262 + 0.30*cos(t)];   % invented, for layout only
    writematrix(ring, cfg.placeholderCsv);
    csvPath = cfg.placeholderCsv;
end
end

function ring = join_ways(ways)
% Chain open ways end-to-end (reversing as needed) into one closed ring.
ring = ways{1}; ways(1) = [];
tol = 1e-7;
while ~isempty(ways)
    found = false;
    for k = 1:numel(ways)
        w = ways{k};
        if norm(ring(end,:) - w(1,:)) < tol
            ring = [ring; w(2:end,:)]; found = true; %#ok<AGROW>
        elseif norm(ring(end,:) - w(end,:)) < tol
            w = flipud(w); ring = [ring; w(2:end,:)]; found = true; %#ok<AGROW>
        end
        if found, ways(k) = []; break; end
    end
    if ~found
        error('Ways do not chain into a single ring (gap > tol).');
    end
end
if norm(ring(1,:) - ring(end,:)) > 1e-6
    warning('BOUNDARY:OPEN', 'Ring not closed; closing it.');
    ring(end+1,:) = ring(1,:);
end
end
