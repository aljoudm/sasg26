function csvPath = build_perimeter(force)
% BUILD_PERIMETER  Union of the Haram polygon (OSM rel 19590020) and the Holy Sites (Mashaeir)
% administrative polygon (OSM rel 19262645) -> one continuous Haram + Arafat boundary.
% PROVISIONAL: the Mashaeir polygon is an OSM admin district, not an official restricted-zone line.
if nargin < 1, force = false; end
cfg = config();
csvPath = cfg.perimeterCsv;
if isfile(csvPath) && ~force, return; end
haram = readmatrix(cfg.boundaryCsv);
rings = osm_relation_rings(cfg.mashaerRelationId, cfg);

pH = polyshape(haram(:,2), haram(:,1), 'Simplify', true);
pM = polyshape();
for k = 1:numel(rings)
    pM = union(pM, polyshape(rings{k}(:,2), rings{k}(:,1), 'Simplify', true));
end
pU = union(pH, pM);
pU = rmholes(pU);
% keep the single largest region (drops slivers)
regs = regions(pU);  [~, im] = max(arrayfun(@area, regs));  pU = regs(im);
v = pU.Vertices;
ring = [v(:,2) v(:,1)];  ring(end+1,:) = ring(1,:);
writematrix(ring, csvPath);
fprintf('Perimeter: Haram + Holy Sites union, %d vertices (regions before keep-largest: %d) -> %s\n', ...
    size(ring,1), numel(regs), csvPath);
end

function rings = osm_relation_rings(relId, cfg)
% Download (if needed) an OSM relation with geometry and chain its outer ways into closed rings.
jsonPath = fullfile(cfg.dataDir, sprintf('mashaer_rel_%d.json', relId));
if ~isfile(jsonPath)
    q = sprintf('[out:json][timeout:90];relation(%d);out geom;', relId);
    opts = weboptions('Timeout', 150, 'UserAgent', 'capstone-das-figure/0.1', ...
        'HeaderFields', {'Accept' '*/*'}, 'ContentType', 'text');
    txt = webwrite('https://overpass-api.de/api/interpreter', 'data', q, opts);
    fid = fopen(jsonPath, 'w', 'n', 'UTF-8'); fwrite(fid, txt); fclose(fid);
end
d = jsondecode(fileread(jsonPath, 'Encoding', 'UTF-8'));
mem = d.elements(1).members;  ways = {};
for k = 1:numel(mem)
    if iscell(mem), m = mem{k}; else, m = mem(k); end
    if strcmp(m.type, 'way') && strcmp(m.role, 'outer') && isfield(m, 'geometry') && ~isempty(m.geometry)
        ways{end+1} = [[m.geometry.lat]' [m.geometry.lon]']; %#ok<AGROW>
    end
end
tol = 1e-7;  rings = {};
while ~isempty(ways)
    ring = ways{1};  ways(1) = [];
    while norm(ring(1,:) - ring(end,:)) > tol
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
        if ~found, error('Relation %d: ways do not close into a ring.', relId); end
    end
    rings{end+1} = ring; %#ok<AGROW>
end
end
