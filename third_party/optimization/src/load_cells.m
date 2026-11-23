function cells = load_cells(P, inDir)
% LOAD_CELLS  Boundary cells of DAS-map (zone, length, risk) AND their order along the boundary.
%
%   cells = load_cells(P)            P from load_params; inputs from ../inputs/dasmap (copies of DAS-map outputs)
%   cells = load_cells(P, inDir)     another folder holding cells.csv, zones.mat, boundary_perimeter.csv
%
% DAS-map numbers its cells in grid-scan order, which says nothing about how they follow each other along the boundary. DAS
% fibre is continuous along the boundary, so the optimization needs that order. It is rebuilt here exactly the way
% DAS-map's zone_classify.m accounts for length: the closed ring is densified at 5 m (planar, local metric frame), each 5 m
% piece falls in a 1 km square, and the square belongs to a merged cell (Z.sqCell). Walking the ring gives "runs": maximal
% stretches of consecutive pieces that stay inside one cell. A cell can have several runs (the boundary may leave a cell
% and come back), so the DAS model works on RUNS and a cell is DAS-covered only if all its runs are.
%
% Output struct fields
%   n, id, zone ('Hot'|'Neutral'|'Cold'), zoneCode (1 Cold, 2 Neutral, 3 Hot), L_m, risk, lambda_mid, lat, lon
%   runs     struct: cell(R,1), s0(R,1), s1(R,1), len(R,1)     [m, arc position from ring start, runs in ring order]
%   cellRuns cell array: runs belonging to each cell
%   ring     struct: x, y (piece centres, local frame [m]), s (arc position of piece centre), len (piece length),
%            cell (cell index of each piece), L (total ring length [m]), lat0, lon0, kx, ky
%   source   provenance text

if nargin < 2 || isempty(inDir)
    inDir = fullfile(fileparts(mfilename('fullpath')), '..', 'inputs', 'dasmap');
end
S   = load(fullfile(inDir, 'zones.mat'), 'Z');   Z = S.Z;
CSV = readtable(fullfile(inDir, 'cells.csv'), 'TextType', 'string');
ring0 = readmatrix(fullfile(inDir, 'boundary_perimeter.csv'));
if norm(ring0(1,:) - ring0(end,:)) > 1e-9, ring0(end+1,:) = ring0(1,:); end

% local metric frame: the same constants as DAS-map main_zones.m / intrinsic_risk_grid.m
lat0 = mean([min(ring0(:,1)) max(ring0(:,1))]);   lon0 = mean([min(ring0(:,2)) max(ring0(:,2))]);
ky = 111195;   kx = 111195 * cosd(lat0);
x = (ring0(:,2) - lon0) * kx;   y = (ring0(:,1) - lat0) * ky;
step = 5;                                                         % m, DAS-map m.zone_step_m
cs = Z.cs;                                                        % cell (square) size [m]

% densify like zone_classify.m (lines 8-12)
seg = hypot(diff(x), diff(y));   mx = []; my = []; ml = [];
for i = 1:numel(seg)
    n = max(ceil(seg(i) / step), 1);   t = ((1:n)' - 0.5) / n;
    mx = [mx; x(i) + t * (x(i+1) - x(i))];  my = [my; y(i) + t * (y(i+1) - y(i))];  ml = [ml; repmat(seg(i) / n, n, 1)]; %#ok<AGROW>
end
% square of each piece -> merged cell. DAS-map's grid origin is a multiple of cs (x0 = floor(min/cs)*cs), so the square index
% is floor(x/cs) and its centre (idx+0.5)*cs; match those centres with Z.sqx_m / Z.sqy_m.
assert(all(abs(mod(Z.sqx_m - cs/2, cs)) < 1e-6) && all(abs(mod(Z.sqy_m - cs/2, cs)) < 1e-6), 'load_cells:grid', 'Unexpected grid origin in zones.mat.');
key = @(ix, iy) ix * 100000 + iy;                                  % integer square keys (indices are small)
sqKey = key(round((Z.sqx_m - cs/2) / cs), round((Z.sqy_m - cs/2) / cs));
[tf, loc] = ismember(key(floor(mx / cs), floor(my / cs)), sqKey);
assert(all(tf), 'load_cells:square', 'A boundary piece falls in a square that DAS-map does not list.');
pieceCell = Z.sqCell(loc);                                         % merged-cell index of every piece, in ring order

% consistency with DAS-map: cell lengths must reproduce Z.Lc_m
Lc = accumarray(pieceCell, ml, [Z.nCells 1]);
assert(max(abs(Lc - Z.Lc_m)) < 1e-6, 'load_cells:length', 'Rebuilt cell lengths differ from DAS-map (max %.3g m).', max(abs(Lc - Z.Lc_m)));

% Runs along the ring. The arc origin is moved to the start of a run (so no run wraps over the origin): the pieces are
% rotated cyclically to begin where the cell changes; arc positions s are measured from that origin.
if all(pieceCell == pieceCell(1)), j0 = 1; else, j0 = find(pieceCell ~= circshift(pieceCell, 1), 1); end
rot = [j0:numel(pieceCell), 1:j0-1]';
mx = mx(rot);  my = my(rot);  ml = ml(rot);  pieceCell = pieceCell(rot);
s = cumsum(ml) - ml/2;   L = sum(ml);
first = find([true; diff(pieceCell) ~= 0]);
last  = [first(2:end) - 1; numel(pieceCell)];
nR = numel(first);
runs = struct('cell', pieceCell(first), 's0', zeros(nR,1), 's1', zeros(nR,1), 'len', zeros(nR,1));
for r = 1:nR
    a = first(r);  b = last(r);
    runs.s0(r) = s(a) - ml(a)/2;   runs.s1(r) = s(b) + ml(b)/2;   runs.len(r) = sum(ml(a:b));
end

% cell attributes
zoneNames = {'Cold', 'Neutral', 'Hot'};
cells = struct();
cells.n = Z.nCells;   cells.id = Z.id;   cells.zoneCode = Z.zone;
cells.zone = zoneNames(Z.zone)';   cells.L_m = Z.Lc_m;   cells.risk = Z.risk;   cells.lambda_mid = Z.lambda(:, 2);
cells.lat = Z.lat;   cells.lon = Z.lon;
% the CSV is DAS-map's own export: it must agree with zones.mat
assert(isequal(string(CSV.zone), string(cells.zone)) && max(abs(CSV.boundary_length_m - cells.L_m)) < 1e-6, 'load_cells:csv', 'cells.csv and zones.mat disagree.');
cells.runs = runs;
cells.cellRuns = arrayfun(@(i) find(runs.cell == i), (1:Z.nCells)', 'UniformOutput', false);
cells.ring = struct('x', mx, 'y', my, 's', s, 'len', ml, 'cell', pieceCell, 'L', L, 'lat0', lat0, 'lon0', lon0, 'kx', kx, 'ky', ky);
cells.source = 'DAS-map commit a25fd0c (zones.mat, cells.csv, boundary_perimeter.csv); run order rebuilt from the ring';
end
