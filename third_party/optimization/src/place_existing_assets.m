function assets = place_existing_assets(P, cells, inDir, verbose)
% PLACE_EXISTING_ASSETS  Positions and boundary coverage of the EXISTING CCTV sites (real locations are not public).
%
%   assets = place_existing_assets(P, cells)            quiet
%   assets = place_existing_assets(P, cells, [], true)  also prints the checkpoint matching table and the site summary
%
% All counts and rules are parameters in load_params.m (P.assets). Nothing here is hard-coded.
%
% SITES
%  * Checkpoints (6, P.assets.checkpoints): each is matched to its road in OSM (DAS-map roads_osm.json, "name" / "name:en" tags
%    with a regex and an allowed highway class). The site is where that road crosses the boundary. If the road does not cross the
%    boundary, the nearest point of the matched road is used and the gap is counted as distance. offset_m (distance of the real
%    checkpoint from that crossing along the road, NaN = unknown = 0) is added. A site is "in" the coverage only if the
%    checkpoint is flagged include AND its distance to the boundary <= P.assets.site_near_boundary_m.
%  * Interdiction points (P.assets.n_interdiction = 32): ASSUMED, placed at crossings of lesser roads (secondary / tertiary first,
%    then the major classes), crossings closer than site_merge_m merged, spread by the farthest-point rule, never within
%    site_merge_m of a checkpoint. If there are fewer crossings than points, the rest are "filler" sites near roads.
%
% COVERAGE (modelling point 1, partial coverage). The cameras of one site watch the same road lanes, so one site covers ONE stretch
% of boundary of P.assets.footprint_m (default Cov_CCTV = 100 m), centred on the site, measured along the boundary; the camera
% count of a site does NOT multiply the coverage. Everything else in the cell (wadis, mountains) stays uncovered. The coverage
% of several sites is a union (overlaps counted once).
%
% Output struct
%   sites      struct array: kind, key, name, piece (ring piece index), s, x, y, cell, nCams, in (logical)
%   checkpointTable  table (one row per checkpoint: matched road, confidence, distance, included?)
%   coverMask  logical per ring piece: covered by at least one "in" site
%   coveredLen_m, coverFrac   per cell
%   nCamsCell  per cell: cameras of the "in" sites located in the cell (reporting only)
%   source

if nargin < 3 || isempty(inDir), inDir = fullfile(fileparts(mfilename('fullpath')), '..', 'inputs', 'dasmap'); end
if nargin < 4, verbose = false; end
v = P.v;   Aa = P.assets;   ring = cells.ring;
rd = read_roads(inDir, ring);
poly = [ring.x; ring.x(1)];   polyY = [ring.y; ring.y(1)];
sub = 1:10:numel(ring.x);   px = ring.x(sub);   py = ring.y(sub);        % candidate boundary points every 50 m (5 m pieces)
rank = containers.Map({'motorway','trunk','primary','secondary','tertiary','motorway_link','trunk_link','primary_link'}, 1:8);
mergeM = Aa.site_merge_m;

% crossings of every road way with the boundary: [x y way]
X = zeros(0, 3);
for k = 1:numel(rd)
    in = inpolygon(rd(k).x, rd(k).y, poly, polyY);
    for q = find(in(1:end-1) ~= in(2:end))'
        X(end+1, :) = [mean(rd(k).x(q:q+1)), mean(rd(k).y(q:q+1)), k]; %#ok<AGROW>
    end
end

%% ---- checkpoints --------------------------------------------------------------------------------------------------
cp = Aa.checkpoints;   nC = numel(cp);
T = table('Size', [nC 14], 'VariableTypes', {'string','string','string','string','double','string','double','double','double','double','double','logical','double','logical'}, ...
    'VariableNames', {'checkpoint','matched_road','osm_ref','highway','osm_way_id','confidence','ways_matched','crossing_clusters','lat','lon','dist_to_boundary_m','flagged_include','offset_m','in_coverage'});
sites = struct('kind', {}, 'key', {}, 'name', {}, 'piece', {}, 's', {}, 'x', {}, 'y', {}, 'cell', {}, 'nCams', {}, 'in', {});
cpPos = zeros(0, 2);
for c = 1:nC
    hit = find(arrayfun(@(r) ~isempty(regexp(r.name + " " + r.en, cp(c).road_pattern, 'once')) && ismember(r.hw, cp(c).highway) ...
        && (cp(c).road_ref == "" || r.ref == cp(c).road_ref), rd));
    T.checkpoint(c) = cp(c).name_en;   T.confidence(c) = cp(c).match_confidence;   T.ways_matched(c) = numel(hit);
    T.flagged_include(c) = cp(c).include;   T.offset_m(c) = cp(c).offset_m;
    if isempty(hit)
        T.matched_road(c) = "NO MATCH";   T.crossing_clusters(c) = 0;   T.dist_to_boundary_m(c) = NaN;   T.in_coverage(c) = false;   continue;
    end
    sel = X(ismember(X(:,3), hit), :);
    if ~isempty(sel)
        [~, o] = sortrows([arrayfun(@(k) rank(char(rd(k).hw)), sel(:,3)), sel(:,1)]);   sel = sel(o, :);       % best road class first
        keep = true(size(sel, 1), 1);
        for a = 1:size(sel, 1), if keep(a), keep(hypot(sel(:,1)-sel(a,1), sel(:,2)-sel(a,2)) < mergeM & (1:size(sel,1))' > a) = false; end, end
        cl = sel(keep, :);   T.crossing_clusters(c) = size(cl, 1);
        pos = cl(1, 1:2);   way = cl(1, 3);   gap = 0;                                                         % the road crosses the boundary
    else
        best = inf;   way = hit(1);   pos = [NaN NaN];
        for k = hit(:)'
            for a = 1:numel(rd(k).x)
                [d, j] = min(hypot(px - rd(k).x(a), py - rd(k).y(a)));
                if d < best, best = d; way = k; pos = [px(j) py(j)]; end
            end
        end
        T.crossing_clusters(c) = 0;   gap = best;                                                              % the road never crosses
    end
    off = cp(c).offset_m;   if isnan(off), off = 0; end
    T.matched_road(c) = rd(way).name + " | " + rd(way).en;   T.osm_ref(c) = rd(way).ref;   T.highway(c) = rd(way).hw;   T.osm_way_id(c) = rd(way).id;
    T.dist_to_boundary_m(c) = gap + off;
    T.in_coverage(c) = cp(c).include && T.dist_to_boundary_m(c) <= Aa.site_near_boundary_m;
    [~, j] = min(hypot(px - pos(1), py - pos(2)));
    T.lat(c) = ring.lat0 + py(j) / ring.ky;   T.lon(c) = ring.lon0 + px(j) / ring.kx;
    sites(end+1) = make_site('checkpoint', cp(c).key, cp(c).name_en, sub(j), ring, Aa.cams_per_checkpoint, T.in_coverage(c)); %#ok<AGROW>
    if T.in_coverage(c), cpPos(end+1, :) = [px(j) py(j)]; end %#ok<AGROW>   % only checkpoints in the coverage keep interdiction points clear
end

%% ---- interdiction points (ASSUMED) --------------------------------------------------------------------------------
nI = Aa.n_interdiction;
lesser = ismember([rd.hw]', ["secondary" "tertiary"]);                 % column, so lesser(X(:,3)) stays a column
pool = X(lesser(X(:,3)), 1:2);   pool2 = X(~lesser(X(:,3)) & ismember([rd(X(:,3)).hw]', Aa.interdiction_road_classes), 1:2);
pool = [pool; pool2];                                                   % lesser roads first, then the major classes
nRawCross = size(pool, 1);
drop = false(size(pool, 1), 1);   dropBy = zeros(1, size(cpPos, 1));
for a = 1:size(pool, 1)                                                 % keep clear of the checkpoints
    if ~isempty(cpPos)
        [dm, jm] = min(hypot(cpPos(:,1) - pool(a,1), cpPos(:,2) - pool(a,2)));
        if dm < mergeM, drop(a) = true; dropBy(jm) = dropBy(jm) + 1; end
    end
end
pool(drop, :) = [];
nAfterDrop = size(pool, 1);
keep = true(size(pool, 1), 1);
for a = 1:size(pool, 1), if keep(a), keep(hypot(pool(:,1)-pool(a,1), pool(:,2)-pool(a,2)) < Aa.interdiction_merge_m & (1:size(pool,1))' > a) = false; end, end
pool = pool(keep, :);
nPool = size(pool, 1);
% farthest-point spread over the pool, starting from the point farthest from every checkpoint
chosen = zeros(0, 2);   ref = cpPos;
for n = 1:min(nI, nPool)
    if isempty(ref), d = inf(size(pool, 1), 1); d(1) = 1; else
        d = inf(size(pool, 1), 1);   for r = 1:size(ref, 1), d = min(d, hypot(pool(:,1) - ref(r,1), pool(:,2) - ref(r,2))); end
    end
    [~, j] = max(d);   chosen(end+1, :) = pool(j, :);   ref(end+1, :) = pool(j, :);   pool(j, :) = []; %#ok<AGROW>
end
for a = 1:size(chosen, 1)
    [~, j] = min(hypot(px - chosen(a,1), py - chosen(a,2)));
    sites(end+1) = make_site('interdiction', sprintf('ip%02d', a), sprintf('interdiction point %d', a), sub(j), ring, Aa.cams_per_interdiction, true); %#ok<AGROW>
end
nFill = nI - size(chosen, 1);
if nFill > 0 && Aa.allow_filler                                                           % too few crossings: filler sites near roads
    rx = vertcat(rd.x);   ry = vertcat(rd.y);   dRoad = inf(numel(px), 1);
    for a = 1:numel(px), dRoad(a) = min(hypot(rx - px(a), ry - py(a))); end
    cand = find(dRoad < v.road_snap_km * 1e3);   ref = [cpPos; chosen];
    for n = 1:nFill
        d = inf(numel(cand), 1);   for r = 1:size(ref, 1), d = min(d, hypot(px(cand) - ref(r,1), py(cand) - ref(r,2))); end
        [~, j] = max(d);   ref(end+1, :) = [px(cand(j)) py(cand(j))];
        sites(end+1) = make_site('filler', sprintf('fill%02d', n), sprintf('filler site %d', n), sub(cand(j)), ring, Aa.cams_per_interdiction, true); %#ok<AGROW>
    end
end

%% ---- coverage: union of one footprint per "in" site --------------------------------------------------------------
half = Aa.footprint_m / 2;   L = ring.L;   mask = false(size(ring.s));
for k = find([sites.in])
    d = abs(ring.s - sites(k).s);   d = min(d, L - d);   mask = mask | d <= half;
end
coveredLen = accumarray(ring.cell, ring.len .* mask, [cells.n 1]);
nCamsCell = accumarray([sites([sites.in]).cell]', [sites([sites.in]).nCams]', [cells.n 1]);

assets = struct('sites', sites, 'checkpointTable', T, 'coverMask', mask, 'coveredLen_m', coveredLen, ...
    'coverFrac', coveredLen ./ cells.L_m, 'nCamsCell', nCamsCell, 'nInterdictionPool', nPool, ...
    'poolInfo', struct('rawCrossings', nRawCross, 'droppedNearCheckpoint', dropBy, 'afterDrop', nAfterDrop, 'afterMerge', nPool, 'checkpointOrder', {{sites([sites.in] & string({sites.kind}) == "checkpoint").key}}), ...
    'source', 'ASSUMED / source-based counts (alwatan_checkpoints, okaz_shumaisi, ajel_32points); positions by road-crossing rule, real locations are not public');

if verbose
    fprintf('\nCheckpoint matching (OSM road -> crossing with the boundary); "near boundary" limit = %g m\n', Aa.site_near_boundary_m);
    disp(T);
    inS = sites([sites.in] & string({sites.kind}) == "checkpoint");   dm = inf;
    for a = 1:numel(inS), for b = a+1:numel(inS), dm = min(dm, hypot(inS(a).x - inS(b).x, inS(b).y - inS(a).y)); end, end
    fprintf('Smallest distance between two checkpoints in the coverage: %.1f km (must not be one shared crossing)\n', dm / 1e3);
    kinds = string({sites.kind});
    fprintf('Sites in coverage: %d checkpoints, %d interdiction (+%d filler); cameras counted: %d; crossings available for interdiction points: %d (wanted %d)\n', ...
        nnz([sites.in] & kinds == "checkpoint"), nnz([sites.in] & kinds == "interdiction"), nnz([sites.in] & kinds == "filler"), sum([sites([sites.in]).nCams]), nPool, nI);
    fprintf('Boundary covered by cameras: %.0f m of %.0f m (%.2f%%); cells touched: %d of %d\n', sum(coveredLen), L, 100*sum(coveredLen)/L, nnz(coveredLen > 0), cells.n);
end
end

function st = make_site(kind, key, name, piece, ring, nCams, in)
st = struct('kind', kind, 'key', string(key), 'name', string(name), 'piece', piece, 's', ring.s(piece), 'x', ring.x(piece), ...
    'y', ring.y(piece), 'cell', ring.cell(piece), 'nCams', nCams, 'in', logical(in));
end

function rd = read_roads(inDir, ring)
% OSM ways with their tags (roads_osm.json from DAS-map) in the local metric frame of the ring.
d = jsondecode(fileread(fullfile(inDir, 'roads_osm.json'), 'Encoding', 'UTF-8'));
els = d.elements;   rd = struct('id', {}, 'hw', {}, 'ref', {}, 'name', {}, 'en', {}, 'x', {}, 'y', {});
tag = @(t, f) string(fielddef(t, f));
for k = 1:numel(els)
    if iscell(els), e = els{k}; else, e = els(k); end
    if ~isfield(e, 'geometry'), continue; end
    t = e.tags;
    rd(end+1) = struct('id', e.id, 'hw', string(t.highway), 'ref', tag(t, 'ref'), 'name', tag(t, 'name'), 'en', tag(t, 'name_en'), ...
        'x', ([e.geometry.lon]' - ring.lon0) * ring.kx, 'y', ([e.geometry.lat]' - ring.lat0) * ring.ky); %#ok<AGROW>
end
end

function s = fielddef(t, f)
if isfield(t, f), s = t.(f); else, s = ''; end
end
