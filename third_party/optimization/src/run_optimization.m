function alloc = run_optimization(cells, P, varargin)
% RUN_OPTIMIZATION  Selective DAS / drone allocation by MILP (intlinprog), exact optimum.
%
%   alloc = run_optimization(cells, P)
%   alloc = run_optimization(cells, P, 'Scenario', struct('name','low','N_drone',3), 'Assets', A, 'Model', M, ...
%                            'ProgressSeconds', 600, 'TimeLimit', Inf, 'Verbose', true)
%
%   cells  from load_cells;  P from load_params (P.v values, P.opts modelling options, P.assets existing-asset parameters)
%
% DECISIONS            y_k    interrogator at run k (a site on the boundary, lead-in L_leadin)
%                      z_r    DAS fibre on boundary run r (the boundary is cut into "runs": maximal stretches inside one cell)
%                      a+/a-  run r is served by the right / left channel of site k (contiguity: a channel serves the runs
%                             between its site and its last run, all carrying fibre; reach <= R_DAS - L_leadin)
%                      sigma  state (x, c) of every cell: DAS fibre or not, and how many drone units watch it from which kind
%                             of station (see coverage_model)
%                      u_sm   drone station s holds m drones (sum of drones <= N_drone of the scenario)
% OBJECTIVE            C_total = (C_DAS_int + C_shelter) * sum(y) + C_fiber * sum(len_r * z_r)   (existing assets cost 0)
% CONSTRAINTS (per cell) detection Pd >= AD0 and, in Hot cells, >= 2 layers at every point (see coverage_model); a DAS state needs
%                      fibre on every run of the cell; drone units need distinct stations within reach holding enough drones;
%                      drones used <= N_drone; (P_DAS + P_shelter) * sum(y) < P0.
% AC0                  main definition: a CHECK on the classifier (Pc_DAS >= AC0, alloc.classifier_check), not a constraint per
%                      cell. The whole-system classification accuracy (conditional on detection) is computed for every cell and
%                      reported (alloc.cells.Pc_system). P.opts.ac0_definition = 'system' turns it into a per-cell constraint.
% Drones are a RESPONSE / VERIFICATION layer (not detection): a Hot cell needs DAS + a station within R_resp with a ready drone.
%
% If no allocation satisfies every cell (e.g. Pd_DAS < AD0, or too few drones for the Hot cells) the result is a SOLUTION WITH A GAP:
%   stage 1 minimises the number of violating cells, stage 1b their total shortfall, stage 2 minimises C_total, stage 3 (C_total fixed) maximises the sum of A_ver over the Hot cells.
%   alloc.violations lists the cells; alloc.min_drones_no_gap = fewest drones (no drone limit) that leave every Hot cell with its verification layer.
% Progress (elapsed time, best solution so far, optimality gap) is printed every ProgressSeconds (default 600 = 10 min).

ip = inputParser;
addParameter(ip, 'Scenario', struct('name', 'custom', 'N_drone', P.v.N_drone_avail));
addParameter(ip, 'Assets', []);   addParameter(ip, 'Model', []);
addParameter(ip, 'ProgressSeconds', 600);   addParameter(ip, 'TimeLimit', Inf);   addParameter(ip, 'Verbose', true);
parse(ip, varargin{:});   o = ip.Results;   scen = o.Scenario;
if ~exist('intlinprog', 'file') || ~license('test', 'Optimization_Toolbox')
    error('run_optimization:toolbox', 'The Optimization Toolbox (intlinprog) is not available. Stop and install / enable it.');
end
t0 = tic;   v = P.v;
if isempty(o.Assets), o.Assets = place_existing_assets(P, cells); end
if isempty(o.Model),  o.Model  = coverage_model(P, cells, o.Assets); end
M = o.Model;   n = cells.n;   K = M.K;   runs = cells.runs;   R = numel(runs.cell);   L = cells.ring.L;
st = M.states;   nStates = numel(st.x);

%% ---- DAS channels: which runs a site can serve on each side (arc distance <= R_DAS - lead-in) -----------------------
Rmax = v.R_DAS_m - v.L_leadin_m;   pos = (runs.s0 + runs.s1) / 2;
chain = cell(R, 2);                                      % {k,1} = right chain (increasing arc), {k,2} = left chain
for k = 1:R
    lst = zeros(1, 0);   j = k;
    for t = 1:R-1, j = mod(j, R) + 1;      if mod(runs.s1(j) - pos(k), L) > Rmax + 1e-9, break; end, lst(end+1) = j; end %#ok<AGROW>
    chain{k, 1} = lst;
    lst = zeros(1, 0);   j = k;
    for t = 1:R-1, j = mod(j - 2, R) + 1;  if mod(pos(k) - runs.s0(j), L) > Rmax + 1e-9, break; end, lst(end+1) = j; end %#ok<AGROW>
    chain{k, 2} = lst;
end

%% ---- cell states: every state of the model (the infeasible ones carry a violation, used only if no complete solution exists) ----
nSig = n * nStates;   sCell = repelem((1:n)', nStates);   sSt = repmat((1:nStates)', n, 1);
okv = reshape(M.ok', [], 1);   Pdv = reshape(M.Pd', [], 1);   Lyv = reshape(M.layers', [], 1);   Pcv = reshape(M.Pc', [], 1);
needv = M.need(sCell);
sViol  = double(~okv);
sShort = max(0, v.AD0 - Pdv) + 0.1 * max(0, needv - Lyv);
if strcmp(M.ac0_definition, 'system'), sShort = sShort + max(0, v.AC0 - Pcv); end
sX = st.x(sSt);

%% ---- variable indexing --------------------------------------------------------------------------------------------------
% Drone stations: a station whose reach set is contained in that of another candidate is never needed (a station can serve any number
% of cells), so only stations with maximal reach sets are kept. This is exact and removes the symmetry of the candidate grid.
cnt = sum(M.reach, 2);   [~, ordS] = sort(cnt, 'descend');   keptSt = zeros(1, 0);
for s = ordS'
    dominated = false;
    for t = keptSt, if all(M.reach(t, :) | ~M.reach(s, :)), dominated = true; break; end, end
    if ~dominated, keptSt(end+1) = s; end %#ok<AGROW>
end
reachU = M.reach(keptSt, :);   xyU = M.stationXY(keptSt, :);   nSt = numel(keptSt);
iy = (1:R)';   iz = R + (1:R)';   off = 2 * R;
nAp = sum(cellfun(@numel, chain(:, 1)));   nAm = sum(cellfun(@numel, chain(:, 2)));
iap = off + (1:nAp)';   off = off + nAp;   iam = off + (1:nAm)';   off = off + nAm;
isg = off + (1:nSig)';  off = off + nSig;
iu  = reshape(off + (1:nSt * K), K, nSt)';   off = off + nSt * K;          % iu(s, m)
nv = off;
if o.Verbose, fprintf('Problem size: %d variables (%d interrogator, %d fibre, %d channel-service, %d cell-state, %d drone-station), %d runs, %d candidate drone stations kept of %d\n', nv, R, R, nAp + nAm, nSig, nSt * K, R, nSt, size(M.stationXY, 1)); end

%% ---- constraints (sparse triplets) --------------------------------------------------------------------------------------
rcols = cell(80000, 1);  rvals = cell(80000, 1);  b = zeros(80000, 1);  row = 0;      % inequality rows
ecols = cell(2000, 1);   evals = cell(2000, 1);    be = zeros(2000, 1);    rowE = 0;       % equality rows
    function addLE(cols, vals, rhs)
        row = row + 1;   rcols{row} = cols(:);   rvals{row} = vals(:);   b(row) = rhs;
    end
    function addEQ(cols, vals, rhs)
        rowE = rowE + 1;   ecols{rowE} = cols(:);   evals{rowE} = vals(:);   be(rowE) = rhs;
    end
servers = cell(R, 1);                                      % for every run: the a-variables that could serve it
cp = iap(1) - 1;  cm = iam(1) - 1;   ap = 0;  am = 0;     % running counters inside the a+ / a- blocks
for k = 1:R
    for side = 1:2
        lst = chain{k, side};
        for t = 1:numel(lst)
            if side == 1, ap = ap + 1; col = cp + ap; else, am = am + 1; col = cm + am; end
            if t == 1, addLE([col, iy(k)], [1 -1], 0);                       % first run of a channel needs the site
            else,      addLE([col, prevCol], [1 -1], 0); end                 % contiguity: run t needs run t-1 of the same channel
            addLE([col, iz(lst(t))], [1 -1], 0);                             % served run carries fibre
            servers{lst(t)}(end+1) = col;                                    %#ok<AGROW>
            prevCol = col;
        end
    end
end
for r = 1:R
    addLE([iy(r), iz(r)], [1 -1], 0);                                        % own run of a site carries fibre
    addLE([iz(r), iy(r), servers{r}], [1, -1, -ones(1, numel(servers{r}))], 0);   % fibre only where a channel serves it
end
for i = 1:n
    q = find(sCell == i);   addEQ(isg(q), ones(numel(q), 1), 1);             % one state per cell
    qx = q(sX(q) == 1);
    for r = cells.cellRuns{i}'                                               % a DAS state needs fibre on every run of the cell
        addLE([isg(qx); iz(r)], [ones(numel(qx), 1); -1], 0);
    end
    reachSt = find(reachU(:, i))';
    for m = 1:K                                                              % units needing a station with >= m drones
        need_m = sum(st.c(sSt(q), m:K), 2);                                  % units of the state that need level >= m
        qq = q(need_m > 0);   if isempty(qq), continue; end
        cols = zeros(1, 0);   for s = reachSt, cols = [cols, iu(s, m:K)]; end %#ok<AGROW>
        addLE([isg(qq); cols(:)], [need_m(need_m > 0); -ones(numel(cols), 1)], 0);
    end
end
for s = 1:nSt, addLE(iu(s, :), ones(1, K), 1); end                            % one drone level per station
droneCols = iu';   droneW = repmat((1:K)', 1, nSt);
addLE(droneCols(:), droneW(:), scen.N_drone);   rowBudget = row;                                 % drones available
% valid cut (tightens the LP bound): one site serves at most 2*(R_DAS - lead-in) of fibre, so total fibre <= 2*Rmax*sum(y)
addLE([iz; iy], [runs.len; -2 * Rmax * ones(R, 1)], 0);
addLE(iy, (v.P_DAS + v.P_shelter) * ones(R, 1), v.P0 - 1e-6);                 % power of the new equipment < P0
nBase = row;
lens = cellfun(@numel, rcols(1:row));   Aineq = sparse(repelem((1:row)', lens), vertcat(rcols{1:row}), vertcat(rvals{1:row}), row, nv);   bineq = b(1:row);
lensE = cellfun(@numel, ecols(1:rowE));   Aeq = sparse(repelem((1:rowE)', lensE), vertcat(ecols{1:rowE}), vertcat(evals{1:rowE}), rowE, nv);   beq = be(1:rowE);
lb = zeros(nv, 1);   ub = ones(nv, 1);   intcon = 1:nv;
if o.Verbose, fprintf('Constraints: %d inequalities, %d equalities, %d nonzeros\n', row, rowE, nnz(Aineq) + nnz(Aeq)); end

%% ---- objectives ---------------------------------------------------------------------------------------------------------
fCost = zeros(nv, 1);
fCost(iy) = v.C_DAS_int + v.C_shelter;   fCost(iz) = v.C_fiber_per_km * runs.len / 1e3;
fViol = zeros(nv, 1);   fViol(isg) = sViol;
fShort = zeros(nv, 1);  fShort(isg) = sShort;
fViolL = zeros(nv, 1);  fViolL(isg) = double(Lyv < needv);                      % states that leave a Hot cell without its 2nd layer
fDrone = zeros(nv, 1);  fDrone(iu(:)) = repelem(1:K, nSt)' + 1e-3;           % drones used (+ tiny per station)
rowOf = @(f) sparse(1, find(f), f(f ~= 0)', 1, nv);
info = struct();

%% ---- stage 1: fewest violating cells (0 when a complete solution exists) ------------------------------------------------------
[x1, f1, fl1, out1] = solve_stage(fViol, Aineq, bineq, Aeq, beq, lb, ub, intcon, 'stage 1: violating cells', o, t0);   %#ok<ASGLU>
if fl1 <= 0, error('run_optimization:infeasible', 'No allocation even with violations allowed (exitflag %d).', fl1); end
nViol = round(f1);   info.stage1 = out1;
Acur = Aineq;   bcur = bineq;
if nViol > 0                                                                  % stage 1b: smallest total shortfall with that many violations
    Acur = [Acur; rowOf(fViol)];   bcur = [bcur; nViol + 0.5];
    [~, f1b, fl1b] = solve_stage(fShort, Acur, bcur, Aeq, beq, lb, ub, intcon, 'stage 1b: shortfall', o, t0);
    if fl1b > 0, Acur = [Acur; rowOf(fShort)];   bcur = [bcur; f1b + 1e-7]; end
else
    Acur = [Acur; rowOf(fViol)];   bcur = [bcur; 0.5];
end
% ---- stage 2: minimum C_total (drones cost nothing for us, so only the DAS part decides the cost) -------------------------------------
[x2, f2, ~, out2] = solve_stage(fCost, Acur, bcur, Aeq, beq, lb, ub, intcon, 'stage 2: C_total', o, t0);
info.stage2 = out2;
% ---- stage 3 (lexicographic): with C_total fixed at its minimum, place the drones so that the sum of the ready-probability A_ver over the
% Hot cells is as large as possible (verification coverage and availability of the cells that need it most). C_total cannot increase. ----
fAver = zeros(nv, 1);   fAver(isg) = -st.a_ver(sSt) .* double(cells.zoneCode(sCell) == 3);
A3 = [Acur; rowOf(fCost)];   b3 = [bcur; f2 + 0.5];
[x3, ~, fl3, out3] = solve_stage(fAver, A3, b3, Aeq, beq, lb, ub, intcon, 'stage 3: max sum of A_ver over Hot cells', o, t0);
if fl3 > 0, x = x3; else, x = x2; end
info.stage3 = out3;
% ---- if the solution has a gap: the fewest drones that would remove it (no drone limit) ----------------------------------------------
minDrones = NaN;
if nViol > 0
    Ab = Aineq;   Ab(rowBudget, :) = 0;   bb = bineq;   bb(rowBudget) = 0;     % drop the drone-budget row
    A4 = [Ab; rowOf(fViolL)];   b4 = [bb; 0.5];                                 % no drone limit; every Hot cell verified (detection gaps cannot be fixed by drones)
    [x4, f4, fl4] = solve_stage(fDrone, A4, b4, Aeq, beq, lb, ub, intcon, 'extra: fewest drones, all Hot cells verified', o, t0);
    if fl4 > 0, minDrones = round(f4 - 1e-3 * nnz(round(x4(iu(:))))); end
end

%% ---- unpack ---------------------------------------------------------------------------------------------------------------
x = round(x);
alloc = struct();
alloc.scenario = scen;   alloc.params = P.v;
y = x(iy) == 1;   z = x(iz) == 1;
alloc.interrogators.run = find(y);   alloc.interrogators.arc_m = pos(y);   alloc.n_interrogators = nnz(y);
[~, pj] = min(abs(cells.ring.s(:)' - pos(y)), [], 2);
alloc.interrogators.lat = cells.ring.lat0 + cells.ring.y(pj) / cells.ring.ky;   alloc.interrogators.lon = cells.ring.lon0 + cells.ring.x(pj) / cells.ring.kx;
alloc.fibre_runs = z;   alloc.fibre_km = sum(runs.len(z)) / 1e3;
alloc.cost.interrogators = nnz(y) * v.C_DAS_int;   alloc.cost.shelters = nnz(y) * v.C_shelter;   alloc.cost.fibre = v.C_fiber_per_km * alloc.fibre_km;
alloc.C_total = alloc.cost.interrogators + alloc.cost.shelters + alloc.cost.fibre;
alloc.fibre_share = alloc.cost.fibre / max(alloc.C_total, eps);                  % share of the fibre in C_total (C_fiber has the weakest source)
alloc.power.interrogators_W = nnz(y) * v.P_DAS;   alloc.power.shelters_W = nnz(y) * v.P_shelter;
alloc.power.total_W = alloc.power.interrogators_W + alloc.power.shelters_W;   alloc.power.P0_W = v.P0;   alloc.power.within_P0 = alloc.power.total_W < v.P0;
sel = find(round(x(isg)) == 1);   assert(numel(sel) == n, 'run_optimization:states', 'Every cell must be in exactly one state.');
sidx = sSt(sel);   [~, ordc] = sort(sCell(sel));   sidx = sidx(ordc);          % chosen state of every cell, in cell order
cellX = st.x(sidx);   cellC = st.c(sidx, :);   cellViol = ~M.ok(sub2ind(size(M.ok), (1:n)', sidx));
U = reshape(x(iu(:)), nSt, K);   nDr = (U * (1:K)')';                          % drones at every candidate station
alloc.drones.station_xy = xyU(nDr > 0, :);   alloc.drones.n = nDr(nDr > 0);   alloc.drones.total = sum(nDr);   alloc.drones.stations = nnz(nDr);
alloc.drones.station_index = keptSt(nDr > 0);   alloc.drones.candidates_kept = nSt;
lin = sub2ind(size(M.Pd), (1:n)', sidx);
unitsTxt = arrayfun(@(i) string(mat2str(cellC(i, :))), (1:n)');
alloc.cells = table((1:n)', string(cells.zone), cellX, sum(cellC, 2), unitsTxt, M.Pd(lin), M.Pc(lin), M.layers(lin), M.need, cellViol, ...
    'VariableNames', {'cell','zone','DAS','drone_units','units_by_station_drones','Pd','Pc_system','layers','layers_needed','violates'});
alloc.cells.Pd_without_DAS_best = M.bestPd0;   alloc.cells.drone_ready_prob = st.a_ver(sidx);   alloc.cells.verified = st.ver(sidx);   alloc.cells.Pd_gap = max(0, v.AD0 - alloc.cells.Pd);
alloc.cells.length_m = cells.L_m;   alloc.cells.fibre_cost = v.C_fiber_per_km * cells.L_m / 1e3 .* cellX;
alloc.cells.camera_fraction = o.Assets.coverFrac;
alloc.cell_state = sidx;   alloc.cell_units = cellC;
alloc.violations = find(cellViol);   alloc.n_violations = numel(alloc.violations);
alloc.detection_gap = struct('cells_below_AD0', nnz(alloc.cells.Pd_gap > 1e-12), 'max', max(alloc.cells.Pd_gap), 'mean', mean(alloc.cells.Pd_gap), 'total', sum(alloc.cells.Pd_gap));   % elastic detection constraint: the shortfall is minimised first, never infeasible
alloc.feasible = alloc.n_violations == 0;
alloc.min_drones_no_gap = minDrones;
alloc.A_ver_hot = struct('sum', sum(alloc.cells.drone_ready_prob(cells.zoneCode == 3)), 'mean', mean(alloc.cells.drone_ready_prob(cells.zoneCode == 3)), 'verified', nnz(alloc.cells.verified & cells.zoneCode == 3));
alloc.classifier_check = struct('Pc_DAS', v.Pc_DAS, 'AC0', v.AC0, 'ok', M.classifier_ok);
alloc.system_accuracy_ok = nnz(alloc.cells.Pc_system >= v.AC0 - 1e-12);          % extra result: whole-system accuracy, conditional on detection
alloc.cells_with_DAS = nnz(cellX);   alloc.cells_with_drone_layer = nnz(st.ver(sidx));   alloc.hot_verified = nnz(st.ver(sidx) & cells.zoneCode == 3);
alloc.cells_per_drone = alloc.cells_with_drone_layer / max(alloc.drones.total, 1);   % realism flag: how many cells each drone is assumed to watch
alloc.solver = info;   alloc.elapsed_s = toc(t0);   alloc.options = P.opts;
if o.Verbose
    fprintf('[%s] scenario %s: C_total %.0f SAR (fibre %.1f%%) | interrogators %d | fibre %.1f km | DAS cells %d/%d | drones %d at %d stations (%d cells with a drone layer) | violations %d | P %.0f W (P0 %.0f W) | %.0f s\n', ...
        datestr(now, 'HH:MM:SS'), scen.name, alloc.C_total, 100 * alloc.fibre_share, alloc.n_interrogators, alloc.fibre_km, alloc.cells_with_DAS, n, alloc.drones.total, alloc.drones.stations, ...
        alloc.cells_with_drone_layer, alloc.n_violations, alloc.power.total_W, v.P0, alloc.elapsed_s);
end
end

function [x, f, flag, out] = solve_stage(f0, A, b, Aeq, beq, lb, ub, intcon, label, o, t0)
% One intlinprog call with a progress printer (every o.ProgressSeconds) and the stage result.
stg = struct('label', label, 'o', o, 't0', t0);
opt = optimoptions('intlinprog', 'Display', 'off', 'RelativeGapTolerance', 1e-9, 'AbsoluteGapTolerance', 1e-6, ...
    'MaxTime', max(1, o.TimeLimit - toc(t0)), 'OutputFcn', @(xx, ov, state) progress(ov, state, stg));
tS = tic;
[x, f, flag, out] = intlinprog(f0, intcon, A, b, Aeq, beq, lb, ub, opt);
if o.Verbose
    if isempty(f), f = NaN; end
    fprintf('  %-32s exitflag %d | objective %.6g | gap %.3g%% | %.1f s\n', label, flag, f, 100 * getfield_def(out, 'relativegap', NaN), toc(tS));
end
end

function stop = progress(ov, state, stg)
% Prints elapsed time, best solution so far and optimality gap every stg.o.ProgressSeconds (10 minutes by default).
persistent tLast;
stop = false;
if strcmp(state, 'init'), tLast = tic; return; end
if ~isempty(tLast) && toc(tLast) >= stg.o.ProgressSeconds && stg.o.Verbose
    fprintf('    [%s | %s] elapsed %.0f s | best solution %.6g | best bound %.6g | gap %.3g%%\n', datestr(now, 'HH:MM:SS'), stg.label, toc(stg.t0), ...
        ov.fval, ov.dualbound, 100 * ov.relativegap);
    tLast = tic;
end
end

function s = getfield_def(st, f, d), if isfield(st, f), s = st.(f); else, s = d; end, end
