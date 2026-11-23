function A = compute_assets(cfg, T, F, roads, poly)
% COMPUTE_ASSETS  Road entry points, CCTV, patrol positions and C2 location (local km coordinates).
%  - Entry points: where major roads (motorway/trunk/primary) cross the perimeter. These stand in for the
%    checkpoints/boundary markers at road entrances (Bawazir et al. 2025); real checkpoint sites are NOT sourced.
%  - CCTV (count, range, FOV), patrols and C2 location are ILLUSTRATIVE scenario choices.
for k = 1:numel(roads)
    roads(k).x = T.toX(roads(k).lon);   roads(k).y = T.toY(roads(k).lat);
end
fibreXY = [F.x F.y];

% --- road entry points
pts = zeros(0, 2);
for k = find(ismember([roads.class], cfg.entryClasses))
    in = inpolygon(roads(k).x, roads(k).y, poly.x, poly.y);
    for q = find(in(1:end-1) ~= in(2:end))'
        pts(end+1, :) = [mean(roads(k).x(q:q+1)), mean(roads(k).y(q:q+1))]; %#ok<AGROW>
    end
end
keep = true(size(pts, 1), 1);                       % merge dual carriageways / links (< 1.5 km apart)
for a = 1:size(pts, 1)
    if ~keep(a), continue; end
    d = hypot(pts(:,1) - pts(a,1), pts(:,2) - pts(a,2));
    keep(d < cfg.entryMergeKm &(1:size(pts,1))' > a) = false;
end
pts = pts(keep, :);
A.entryIdx = knnsearch(fibreXY, pts);               % snap to the fibre
A.entry = [F.x(A.entryIdx), F.y(A.entryIdx), F.z(A.entryIdx)];

% --- CCTV: one at each entry point, the rest spread along the fibre near roads (< 500 m)
tmp = arrayfun(@(r) [r.x r.y], roads, 'UniformOutput', false);
allRoad = vertcat(tmp{:});
[~, dr] = knnsearch(allRoad, fibreXY);
cand = find(dr < cfg.cctvRoadKm);
camIdx = A.entryIdx(:);
while numel(camIdx) < cfg.nCCTV && ~isempty(cand)
    d = min(pdist2(fibreXY(cand, :), fibreXY(camIdx, :)), [], 2);
    [~, j] = max(d);   camIdx(end+1, 1) = cand(j); %#ok<AGROW>
end
A.roadPts = allRoad;                                % all road vertices [km], used by the scene builder
A.cctv = struct('x', {}, 'y', {}, 'z', {}, 'gz', {}, 'heading', {}, 'idx', {}, 'lat', {}, 'lon', {});
for k = 1:numel(camIdx)
    i = camIdx(k);   [nx, ny] = outward_normal(F, i, poly);
    A.cctv(k) = struct('x', F.x(i), 'y', F.y(i), 'z', F.z(i), 'gz', T.heightXY(F.x(i), F.y(i)), ...
        'heading', atan2(ny, nx), 'idx', i, 'lat', F.lat(i), 'lon', F.lon(i));
end

% --- patrols: road points 0.4-1.6 km from the fibre, spread out
isMain = ismember([roads.class], ["motorway" "trunk" "primary" "secondary" "tertiary"]);
tmp = arrayfun(@(r) [r.x r.y], roads(isMain), 'UniformOutput', false);
rp = vertcat(tmp{:});
[~, dF] = knnsearch(fibreXY, rp);
pc = rp(dF > cfg.patrolBandKm(1) & dF < cfg.patrolBandKm(2), :);
sel = pc(randi(size(pc, 1)), :);
while size(sel, 1) < cfg.nPatrol
    d = min(pdist2(pc, sel), [], 2);   [~, j] = max(d);   sel(end+1, :) = pc(j, :); %#ok<AGROW>
end
A.patrol = [sel, arrayfun(@(x, y) T.heightXY(x, y), sel(:,1), sel(:,2)) + 0.05];

% --- C2 centre: area centroid of the perimeter (ILLUSTRATIVE location)
[cx, cy] = centroid(polyshape(poly.x, poly.y));
A.c2 = [cx, cy, T.heightXY(cx, cy) + 0.05];
fprintf('Assets          : %d road entry points, %d CCTV, %d patrols (illustrative)\n', size(A.entry,1), numel(A.cctv), size(A.patrol,1));
end
