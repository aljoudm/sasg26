function M = coverage_model(P, cells, assets, reachCache)
% COVERAGE_MODEL  Detection / verification / layers of every cell for every possible allocation state, plus drone response reach.
%
%   M = coverage_model(P, cells, assets)
%   M = coverage_model(P, cells, assets, reachCache)   reuse M.reach / M.stationXY (valid for the same R_resp)
%
% ROLES (decision of 22 Nov): DETECTION (AD0) comes from DAS and the existing cameras ONLY. Drones are a RESPONSE / VERIFICATION
% layer: after an alarm a drone from a station within reach verifies the event. Alarm -> camera or drone -> verification.
%
% A cell is described by a STATE (x, c): x = 1 if DAS fibre is installed in the cell; c = (c_1 ... c_K), c_m = number of drone stations
% holding m drones that serve the cell (at most Q = opts.max_drone_units stations). Everything else (existing cameras, partial
% coverage) is fixed input. All values are precomputed constants, so the MILP stays linear and exact.
%
% MODEL (independence between sensors is assumed everywhere)
%  * Intruder position uniform along the cell. A piece of boundary is covered by an existing camera (fraction f_i =
%    assets.coverFrac(i)) or not (1 - f_i). DAS covers the whole cell when x = 1.
%  * DETECTION at a point: 1 - prod(1 - d_j) over DAS and (if covered) the camera; cell value = length-weighted average.
%  * DRONE AVAILABILITY: one drone flies T_drone and recharges T_charge: A1 = T/(T + T_charge); a station with m drones has a
%    ready drone with probability A(m) = min(1, m*A1). Probability that some serving station has a ready drone:
%    a_ver = 1 - prod over serving stations (1 - A(m)).
%  * REACH: a station serves a cell if the farthest point of the cell is within R_resp = min(Cov_drone, v_drone*(T_resp - T_launch)).
%  * VERIFICATION LAYER of a cell: present if a station serves it and a_ver >= A_ver_min (drone), (a camera counts only if it covers the
%    whole cell, f = 1, which never happens: cameras cover a 100 m stretch per site).
%  * LAYERS (Hot cells need >= 2 independent layers at EVERY point): layers = x (detection) + [verification] + [f = 1].
%  * CLASSIFICATION of the whole system (extra result, NOT a constraint): the sensors that detected vote (weighted vote, only a sensor
%    that detected can classify), and a verifying drone (accuracy Pc_drone), ready with probability a_ver, adds its vote.
%    Pc_i = E[correct and detected] / E[detected]. AC0 itself is a CHECK on the classifier (Pc_DAS >= AC0, M.classifier_ok).
%    With opts.ac0_definition = 'system' the whole-system accuracy becomes a per-cell constraint instead.
%
% Output struct (arrays indexed (cell, state))
%   states (x, c, units, a_ver, ver, text), Pd, PdWorst, Pc, Pc_or, Pc_max, layers, need, ok, okDet
%   A, K, Q, A1, classifier_ok, cellOk, bestPd0 (best Pd of a cell WITHOUT DAS), bestPc, reach (station, cell), stationXY, R_resp

v = P.v;   o = P.opts;   ring = cells.ring;   n = cells.n;
if v.use_PS && any(isnan([v.Pd_PS_value v.Pc_PS_value v.Cov_PS_value])), error('coverage_model:PS', 'Point-Sensor values are TBD: set use_PS = false or fill them in load_params.'); end

A1 = v.T_drone_min / (v.T_drone_min + v.T_charge_min);
K  = ceil(1 / A1 - 1e-12);
Ak = min(1, (0:K) * A1);
Q  = o.max_drone_units;
f  = assets.coverFrac(:);

C = zeros(1, K);                                           % all count vectors with sum <= Q
for q = 1:Q, C = [C; count_vectors(K, q)]; end %#ok<AGROW>
nC = size(C, 1);   S = 2 * nC;
st.x = [zeros(nC, 1); ones(nC, 1)];   st.c = [C; C];   st.units = sum(st.c, 2);
st.a_ver = 1 - prod((1 - Ak(2:end)) .^ st.c, 2);           % probability that a drone is ready
st.ver = st.units >= 1 & st.a_ver >= v.A_ver_min - 1e-12;  % verification layer present
st.text = strings(S, 1);
for s = 1:S, st.text(s) = sprintf('x=%d c=%s', st.x(s), mat2str(st.c(s, :))); end

Pd = zeros(n, S);   PdW = Pd;   Pc = Pd;   Pc_or = Pd;   Pc_max = Pd;   layers = Pd;
cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
for s = 1:S
    base = zeros(0, 2);
    if st.x(s) == 1, base(end+1, :) = [v.Pd_DAS, v.Pc_DAS]; end                          %#ok<AGROW>
    cov = [base; v.Pd_CCTV, v.Pc_CCTV];
    [d0, n0, o0, m0] = piece_stats(base, o.classification_fusion, cache, st.a_ver(s), v.Pc_drone);   % piece without a camera
    [d1, n1, o1, m1] = piece_stats(cov,  o.classification_fusion, cache, st.a_ver(s), v.Pc_drone);   % piece covered by a camera
    Pd(:, s)     = (1 - f) * d0 + f * d1;
    PdW(:, s)    = d0;   PdW(f > 0, s) = min(d0, d1);
    den = max(Pd(:, s), eps);
    Pc(:, s)     = ((1 - f) * n0 + f * n1) ./ den;
    Pc_or(:, s)  = ((1 - f) * o0 + f * o1) ./ den;
    Pc_max(:, s) = ((1 - f) * m0 + f * m1) ./ den;
    layers(:, s) = st.x(s) + double(st.ver(s)) + (f >= 1 - 1e-12);
end
Pc(Pd < 1e-12) = 0;   Pc_or(Pd < 1e-12) = 0;   Pc_max(Pd < 1e-12) = 0;
need = ones(n, 1);   need(cells.zoneCode == 3) = o.hot_min_layers;
okDet = (Pd >= v.AD0 - 1e-12) & (layers >= need);
classifier_ok = v.Pc_DAS >= v.AC0 - 1e-12;
switch o.ac0_definition
    case 'classifier', okClass = true(n, S);                 % a check on the classifier, not a per-cell constraint
    case 'system',     okClass = Pc >= v.AC0 - 1e-12;        % whole-system accuracy per cell
    otherwise, error('coverage_model:ac0', 'Unknown ac0_definition %s', o.ac0_definition);
end
ok = okDet & okClass;

M = struct('states', st, 'Pd', Pd, 'PdWorst', PdW, 'Pc', Pc, 'Pc_or', Pc_or, 'Pc_max', Pc_max, 'layers', layers, 'need', need, 'ok', ok, 'okDet', okDet, ...
    'A', Ak, 'K', K, 'Q', Q, 'A1', A1, 'fusion', o.classification_fusion, 'ac0_definition', o.ac0_definition, 'classifier_ok', classifier_ok, 'R_resp', v.R_resp_m);
M.cellOk = any(ok, 2);
M.bestPd0 = max(Pd(:, st.x == 0), [], 2);                   % best detection a cell can get WITHOUT DAS (cameras only)
M.bestPc = max(Pc, [], 2);
M.idx = @(x, c) find(st.x == x & all(st.c == reshape(c, 1, []), 2), 1);

% drone response reach: candidate stations = boundary points every 500 m + interior grid every 2 km (ASSUMED: dock sites are not public)
if nargin >= 4 && ~isempty(reachCache) && isfield(reachCache, 'radius') && abs(reachCache.radius - v.R_resp_m) < 1e-9
    M.reach = reachCache.reach;   M.stationXY = reachCache.stationXY;   M.reach_radius = reachCache.radius;   return;
end
sub = 1:100:numel(ring.x);   sx = [ring.x(sub) ring.y(sub)];
[gx, gy] = meshgrid(floor(min(ring.x)/2000)*2000 : 2000 : max(ring.x), floor(min(ring.y)/2000)*2000 : 2000 : max(ring.y));
inn = inpolygon(gx(:), gy(:), [ring.x; ring.x(1)], [ring.y; ring.y(1)]);   sx = [sx; gx(inn) gy(inn)];
sp = 1:10:numel(ring.x);   px = ring.x(sp);   py = ring.y(sp);   pcell = ring.cell(sp);
reach = false(size(sx, 1), n);
for s = 1:size(sx, 1)
    far = accumarray(pcell, hypot(px - sx(s,1), py - sx(s,2)), [n 1], @max);   % farthest boundary point of every cell
    reach(s, :) = (far <= v.R_resp_m)';
end
M.reach = reach;   M.stationXY = sx;   M.reach_radius = v.R_resp_m;
end

function R = count_vectors(K, q)
% all count vectors (c_1..c_K) of non-negative integers with sum exactly q (stars and bars)
if K == 1, R = q; return; end
comb = nchoosek(1:(K + q - 1), K - 1);   R = zeros(size(comb, 1), K);
for r = 1:size(comb, 1), R(r, :) = diff([0 comb(r, :) K + q]) - 1; end
end

function [det, numCorrect, numCorrectOr, numCorrectMax] = piece_stats(S, mode, cache, aVer, pcDrone)
% S: rows [d_j, pc_j] of the sensors that can DETECT on one piece of boundary. A verifying drone (ready with probability aVer,
% accuracy pcDrone) adds its vote to every detected event. det = P(detected by any); numCorrect = E[detected and correctly classified]
% under the chosen fusion rule; numCorrectOr / numCorrectMax = the optimistic / no-fusion bounds.
m = size(S, 1);
if m == 0, det = 0; numCorrect = 0; numCorrectOr = 0; numCorrectMax = 0; return; end
d = S(:, 1)';   c = S(:, 2)';
det = 1 - prod(1 - d);   numCorrect = 0;   numCorrectOr = 0;   numCorrectMax = 0;
for mask = 1:2^m - 1                                   % non-empty subsets of sensors that detected
    in = bitget(mask, 1:m) == 1;   pr = prod(d(in)) * prod(1 - d(~in));
    r0 = fuse_cached([c(in)], mode, cache);   r1 = fuse_cached([c(in) pcDrone], mode, cache);
    r = aVer * r1 + (1 - aVer) * r0;
    numCorrect = numCorrect + pr * r(1);   numCorrectOr = numCorrectOr + pr * r(2);   numCorrectMax = numCorrectMax + pr * r(3);
end
end

function r = fuse_cached(c, mode, cache)
key = sprintf('%s|%s', mode, sprintf('%.12g,', sort(c)));
if isKey(cache, key), r = cache(key); else
    r = [fuse_classification(c, mode), fuse_classification(c, 'independent_or'), fuse_classification(c, 'max')];   cache(key) = r;
end
end
