function out = fetch_boundary_sudair(force)
% FETCH_BOUNDARY_SUDAIR  Stage A. Overpass: solar power plants in the bbox (list + area), the Sudair way geometry, substations
% touching/inside it, and access roads. Adapted from DAS-map data/fetch_boundary_osm.m / fetch_roads_osm.m (site inputs changed only).
if nargin < 1, force = false; end
c = sasg_config();  out = struct();
opq = @(q) overpass(c, q);
bb = sprintf('%.4f,%.4f,%.4f,%.4f', c.bbox);
%% 1 candidates
fc = fullfile(c.dataDir, 'osm_candidates.json');
if ~isfile(fc) || force
    wr(fc, opq(['[out:json][timeout:90];(way["power"="plant"]["plant:source"="solar"](' bb ');relation["power"="plant"]["plant:source"="solar"](' bb '););out geom tags;']));
end
d = jsondecode(fileread(fc, 'Encoding', 'UTF-8'));  els = d.elements;
fprintf('Candidates (power=plant, plant:source=solar) in bbox [%s]:\n', bb);
for k = 1:numel(els)
    e = el(els, k);
    if isfield(e, 'geometry'), r = [[e.geometry.lat]' [e.geometry.lon]']; a = ring_area_km2(r); else, a = NaN; end
    nm = ''; if isfield(e.tags, 'name_en'), nm = e.tags.name_en; end
    fprintf('  %s %d  area %.2f km2  %s\n', e.type, e.id, a, nm);
end
%% 2 selected ring
e = []; for k = 1:numel(els), if el(els, k).id == c.osmWayId, e = el(els, k); end, end
if isempty(e), error('Sudair way %d not among candidates.', c.osmWayId); end
ring = [[e.geometry.lat]' [e.geometry.lon]'];
if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end
writematrix(ring, c.boundaryCsv);
[L_hav, L_pl, A] = ring_lengths(ring);
out.ring = ring; out.L_haversine_km = L_hav; out.L_planar_km = L_pl; out.area_km2 = A;
fprintf('Sudair way %d: %d vertices, area %.2f km2 (published %.1f, dev %+.1f%%), L_haversine %.3f km, L_planar %.3f km\n', ...
    c.osmWayId, size(ring,1), A, c.area_pub_km2, 100*(A/c.area_pub_km2-1), L_hav, L_pl);
out.areaDevPct = 100 * (A / c.area_pub_km2 - 1);
if abs(A / c.area_pub_km2 - 1) > c.area_tol, error('AREA:GATE', 'Area %.2f km2 outside +/-10%% of %.1f km2 - STOP and report.', A, c.area_pub_km2); end
%% 3 substations (plant bbox + 0.01 deg)
m = 0.01; sb = sprintf('%.5f,%.5f,%.5f,%.5f', min(ring(:,1))-m, min(ring(:,2))-m, max(ring(:,1))+m, max(ring(:,2))+m);
fs = fullfile(c.dataDir, 'osm_substations.json');
if ~isfile(fs) || force, wr(fs, opq(['[out:json][timeout:90];(way["power"="substation"](' sb ');relation["power"="substation"](' sb ');node["power"="substation"](' sb '););out geom tags;'])); end
ds = jsondecode(fileread(fs, 'Encoding', 'UTF-8'));  rows = {};  S = struct('g', {}, 'inside', {}, 'id', {}, 'voltage', {});
for k = 1:numel(ds.elements)
    e = el(ds.elements, k);
    if isfield(e, 'geometry') && isstruct(e.geometry), g = [[e.geometry.lat]' [e.geometry.lon]']; else, g = [e.lat e.lon]; end
    tg = e.tags; nm = ''; if isfield(tg, 'name'), nm = tg.name; end; vv = ''; if isfield(tg, 'voltage'), vv = tg.voltage; end
    inside = any(inpolygon(g(:,2), g(:,1), ring(:,2), ring(:,1)));
    fprintf('  substation %s %d voltage=%s vertices=%d touchesPlant=%d\n', e.type, e.id, vv, size(g,1), inside);
    rows(end+1, :) = {e.id, string(e.type), string(vv), string(nm), mean(g(:,1)), mean(g(:,2)), size(g,1), inside}; %#ok<AGROW>
    S(end+1) = struct('g', g, 'inside', inside, 'id', e.id, 'voltage', vv); %#ok<AGROW>
end
if isempty(rows), warning('No substation found in OSM near the plant.'); T = table(); else
T = cell2table(rows, 'VariableNames', {'osm_id','type','voltage','name','lat','lon','nvert','inside_or_touching_plant'});
writetable(T, c.substationCsv, 'Encoding', 'UTF-8'); end
save(fullfile(c.dataDir, 'substations.mat'), 'S');
out.substations = T;
%% 4 roads
fr = fullfile(c.dataDir, 'roads_osm.json');
rb = sprintf('%.4f,%.4f,%.4f,%.4f', min(ring(:,1))-0.08, min(ring(:,2))-0.08, max(ring(:,1))+0.08, max(ring(:,2))+0.08);
if ~isfile(fr) || force
    wr(fr, opq(['[out:json][timeout:180];way["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|service|track|motorway_link|trunk_link|primary_link)$"](' rb ');out geom tags;']));
end
dr = jsondecode(fileread(fr, 'Encoding', 'UTF-8'));  roads = struct('class', {}, 'lat', {}, 'lon', {});
for k = 1:numel(dr.elements)
    e = el(dr.elements, k); if ~isfield(e, 'geometry'), continue; end
    roads(end+1) = struct('class', string(e.tags.highway), 'lat', [e.geometry.lat]', 'lon', [e.geometry.lon]'); %#ok<AGROW>
end
save(fullfile(c.dataDir, 'roads_osm.mat'), 'roads');
fprintf('Roads: %d ways (%s)\n', numel(roads), strjoin(unique([roads.class]), ','));
out.nRoads = numel(roads);
end
function e = el(els, k), if iscell(els), e = els{k}; else, e = els(k); end, end
function wr(p, t), fid = fopen(p, 'w', 'n', 'UTF-8'); fwrite(fid, t); fclose(fid); end
function txt = overpass(c, q)
opts = weboptions('Timeout', 200, 'UserAgent', c.UA, 'HeaderFields', {'Accept' '*/*'}, 'ContentType', 'text');
for a = 1:4
    try, txt = webwrite('https://overpass-api.de/api/interpreter', 'data', q, opts); return;
    catch err, if a == 4, rethrow(err); end, pause(15); end
end
end
