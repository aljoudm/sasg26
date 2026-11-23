function P = load_params(tsvFile)
% LOAD_PARAMS  Single parameter source of the optimization module.
%
%   P = load_params()            reads ../parameters_reviewed.tsv (relative to this file)
%   P = load_params(tsvFile)     reads another copy of the table
%
%   Every number comes from parameters_reviewed.tsv EXCEPT the two clearly marked blocks below:
%     (1) ASSUMED  block : values the project brief / DAS-map README state but the table lacks.
%     (2) PLACEHOLDER block : values the table marks TBD (or lacks entirely). They are NOT real.
%   Each value in P.v has a tag in P.tag and a human-readable source in P.src.
%
%   Internal units (P.v): length [m], power [W], cost [SAR], time [min], probabilities in [0,1].
%
%   Output fields
%     P.v        flat struct of values used by the model
%     P.tag      same field names -> 'TABLE' | 'TABLE-DERIVED' | 'ASSUMED' | 'PLACEHOLDER' | 'DERIVED-PROPOSED'
%     P.src      same field names -> source / note text
%     P.range    sensitivity ranges for PLACEHOLDER (and doubtful) values, [lo hi]
%     P.raw      all table rows (symbol, value text, unit, source, status, note)
%     P.opts     modelling switches (defaults = recommended options, can be overridden by the caller)

if nargin < 1 || isempty(tsvFile)
    tsvFile = fullfile(fileparts(mfilename('fullpath')), '..', 'parameters_reviewed.tsv');
end
assert(isfile(tsvFile), 'load_params:noFile', 'Parameter table not found: %s', tsvFile);

%% ---- 1. read the table (tab separated, UTF-8, header row, 9 columns) -------------------------------------
txt   = fileread(tsvFile, 'Encoding', 'UTF-8');
lines = splitlines(string(txt));
lines = lines(strlength(strtrim(lines)) > 0);
lines(1) = [];                                         % header
raw = struct('sym', {}, 'value', {}, 'unit', {}, 'source', {}, 'status', {}, 'note', {});
seen = containers.Map('KeyType', 'char', 'ValueType', 'double');
for r = 1:numel(lines)
    c = split(lines(r), char(9));
    assert(numel(c) == 9, 'load_params:badRow', 'Row %d of the table has %d columns (expected 9).', r + 1, numel(c));
    sym = char(strtrim(c(1)));
    if isKey(seen, sym), seen(sym) = seen(sym) + 1; sym = sprintf('%s_dup%d', sym, seen(sym));
    else,                seen(sym) = 1; end
    raw(end+1) = struct('sym', sym, 'value', strtrim(c(4)), 'unit', strtrim(c(5)), 'source', strtrim(c(6)), ...
                        'status', strtrim(c(8)), 'note', strtrim(c(9))); %#ok<AGROW>
end
names = {raw.sym};
row = @(s) raw(strcmp(names, s));                       % table row by symbol (errors below if missing)
num = @(s) parse_number(row(s).value);                   % numeric value of a row, NaN if TBD / not a number

v = struct();  tag = struct();  src = struct();  rng = struct();
    function put(name, value, tg, source)               % register one value with its tag and source
        v.(name) = value;  tag.(name) = tg;  src.(name) = char(source);
    end
    function need(s)
        assert(any(strcmp(names, s)), 'load_params:missingRow', 'Symbol %s is not in the table.', s);
    end

%% ---- 2. values taken directly from the table --------------------------------------------------------------
cellfun(@need, {'AD0','R_DAS','N_ch_DAS','N_ch_active','P_DAS','C_DAS_int','C_fiber','L_boundary','L_leadin', ...
    'Cov_CCTV','P_CCTV','Pd_CCTV','Pc_CCTV','C_CCTV','Cov_drone','P_drone','T_drone','Pd_drone','C_drone', ...
    'N_drone_avail','cell_size','R_hot','R_cold','N_cells','L_zone','P0','P_shelter','Pd_DAS','Pc_DAS','Pc_drone', ...
    'Pd_PS','Pc_PS','Cov_PS','P_PS','C_PS','AC0','T_charge','lambda_cold','FAR','C_shelter','v_drone','T_launch','T_resp','A_ver_min','R_resp'});

put('AD0',          num('AD0')/100,        'TABLE', 'AD0, status approved');
put('R_DAS_m',      num('R_DAS')*1e3,      'TABLE', 'R_DAS (20 km option, FEBUS A1-NEO datasheet)');
put('N_ch_DAS',     num('N_ch_DAS'),       'TABLE', 'N_ch_DAS (installed channels per unit)');
put('N_ch_active',  num('N_ch_active'),    'TABLE', 'N_ch_active (one channel per direction along the boundary)');
put('P_DAS',        num('P_DAS'),          'TABLE', 'P_DAS (datasheet, approximate ~170 W)');
put('C_DAS_int',    num('C_DAS_int'),      'TABLE', 'C_DAS_int: 150,000 EUR x 4.24 SAR/EUR (FX ASSUMED, provisional)');
put('L_leadin_m',   num('L_leadin'),       'TABLE', 'L_leadin (cabin assumed ON the boundary)');
put('Cov_CCTV_m',   num('Cov_CCTV'),       'TABLE', 'Cov_CCTV (no written source in the table)');
put('P_CCTV',       num('P_CCTV'),         'TABLE', 'P_CCTV (Hikvision / Dahua datasheets)');
put('Pd_CCTV',      num('Pd_CCTV')/100,    'TABLE', 'Pd_CCTV (Park et al., Table 3)');
put('Pc_CCTV',      num('Pc_CCTV')/100,    'TABLE', 'Pc_CCTV (Jebur et al., Table 5)');
put('Cov_drone_m',  num('Cov_drone')*1e3,  'TABLE', 'Cov_drone = operating RADIUS (proposal)');
put('P_drone',      num('P_drone'),        'TABLE', 'P_drone (peak figures, slightly pessimistic; proposal)');
put('T_drone_min',  num('T_drone'),        'TABLE', 'T_drone flight time per charge (proposal)');
put('Pd_drone',     num('Pd_drone')/100,   'TABLE', 'Pd_drone (average of 3 UAV thermal studies; proposal)');
put('cell_size_m',  num('cell_size'),      'TABLE', 'cell_size (DAS-map, provisional)');
put('R_hot',        num('R_hot'),          'TABLE', 'R_hot (DAS-map k-means, provisional)');
put('R_cold',       num('R_cold'),         'TABLE', 'R_cold (DAS-map k-means, provisional)');
% L_boundary: the table column is rounded (145.5 km); the exact haversine value is quoted in the review note.
tok = regexp(char(row('L_boundary').note), '([\d,]+\.\d+)\s*m', 'tokens', 'once');
assert(~isempty(tok), 'load_params:LB', 'Exact L_boundary not found in the L_boundary note.');
put('L_boundary_m', str2double(strrep(tok{1}, ',', '')), 'TABLE', 'L_boundary exact value quoted in the review note (provisional: Arafat part)');
assert(abs(v.L_boundary_m/1e3 - num('L_boundary')) < 0.05, 'load_params:LB2', 'L_boundary note and column disagree.');
% zone counts / lengths ("139 (36 / 56 / 47)" and "39.4 / 59.0 / 47.1"), order Hot / Neutral / Cold
n3 = sscanf(strrep(strrep(char(row('N_cells').value), '/', ' '), '(', ' '), '%f')';   % [139 36 56 47]
assert(numel(n3) == 4 && n3(1) == sum(n3(2:4)), 'load_params:Ncells', 'N_cells row is inconsistent.');
put('N_cells_zone', n3(2:4), 'TABLE', 'N_cells row, order Hot / Neutral / Cold');
l3 = sscanf(strrep(char(row('L_zone').value), '/', ' '), '%f')';
put('L_zone_km', l3, 'TABLE', 'L_zone row, order Hot / Neutral / Cold');
% reference costs (existing assets cost us ZERO in the optimization; kept for comparison only)
put('C_CCTV_ref',  num('C_CCTV'),  'TABLE', 'C_CCTV, reference only (existing asset: zero cost for us)');
put('C_drone_ref', num('C_drone'), 'TABLE', 'C_drone, reference only (existing asset: zero cost for us)');
put('C_existing',  0,              'ASSUMED', 'Project rule: existing CCTV / drones / Point-Sensor Networks have zero capital cost for us');

%% ---- 3. ASSUMED block (stated by the brief / DAS-map README, not a table value) ---------------------------
% AC0 is read from the table (row AC0), see section 4b.
put('N_drone_avail', num('N_drone_avail'), 'ASSUMED', 'N_drone_avail = 3 (table: ILLUSTRATIVE; real number not public)');
put('road_snap_km', 0.5, 'ASSUMED', 'filler cameras only within 500 m of a road (table row Loc_existing, DAS-map method)');

%% ---- 3b. EXISTING ASSETS (all counts / places are parameters: edit HERE only) ------------------------------------
% The DAS-map counts (16 cameras, 3 drones, 5 patrols) are ILLUSTRATIVE and NOT used. Realistic basis (official sources,
% BibTeX keys in the project .bib): 6 entrance checkpoints [alwatan_checkpoints]; 16 cameras on the vehicle lanes of the
% Al-Shumaisi checkpoint [okaz_shumaisi] -> assumed ~16 cameras per checkpoint; 32 interdiction points on the outskirts and
% access roads [ajel_32points], camera count per point NOT published; drones used against unauthorized entry, number
% NOT published [yenisafak2026drones].
A = struct();
mk = @(key, en, ar, pat, ref, hw, conf, inc, why) struct('key', key, 'name_en', en, 'name_ar', ar, 'road_pattern', pat, ...
    'road_ref', ref, 'highway', {hw}, 'match_confidence', conf, 'include', inc, 'include_reason', why, 'offset_m', NaN);
% road_ref: OSM "ref" the way must carry ("" = any). Checked against the OSM data of DAS-map (names, refs, geometry):
%   Hada     = Taif road via Al-Kara / Al-Hada, ref 15 (OSM name "طريق الكرا الهدا"; it crosses the boundary on the east side);
%   Sharaye  = Taif road via Al-Sail = ref 40 east of Makkah (OSM names "King Faisal Road" -> "Makkah Al-Mukarramah Road", ref 40,
%              the continuation of the Jeddah expressway). OSM does NOT carry the word "Sail": this identification rests on the
%              ref-40 continuity east of Makkah and on the project lead's statement, not on a road name in the data.
%   Note: "طريق الأمير سلطان / At Taif Road" (ref 15) is the SAME Taif-Hada road as the Hada one (the ways join), so it is NOT used for Al-Sharaye.
% road_pattern: regex tested on the OSM "name" + "name:en" of each way (DAS-map roads_osm.json). The checkpoint position is
% the crossing of the matched road with the boundary (project lead's rule). offset_m = distance of the real checkpoint from that
% crossing ALONG the road (NaN = unknown -> treated as 0). A checkpoint farther than site_near_boundary_m is excluded.
A.checkpoints = [ ...
    mk('shumaisi_new', 'Al-Shumaisi (new)', 'الشميسي الجديد', 'Jeddah.?Makkah Expressway|Makkah-Jeddah Expressway|جدة - مكة السريع', "40", ["motorway"], 'high', true, 'on the boundary by crossing rule'), ...
    mk('shumaisi_old', 'Al-Shumaisi old (Hudaybiyah)', 'الشميسي القديم (الحديبية)', 'Old Makkah|Old Mecca|مكة القديم', "290", ["trunk" "primary"], 'medium', true, 'on the boundary by crossing rule'), ...
    mk('sharaye', 'Al-Sharaye (Taif road via Al-Sail)', 'الشرائع', 'King Faisal Road|طريق الملك فيصل|Makkah Al-Mukarramah|طريق مكة المكرمة', "40", ["motorway"], 'medium', true, 'on the boundary by crossing rule; road = ref 40 east of Makkah (identification: ref continuity + project lead, no "Sail" name in OSM)'), ...
    mk('hada', 'Al-Hada (Taif road via Al-Hada)', 'الهدا', 'Al Hada|الكرا الهدا|الهدا', "15", ["motorway" "trunk" "primary"], 'high', true, 'on the boundary by crossing rule; real distance NOT verified (offset_m unknown)'), ...
    mk('nawariyah', 'Al-Nawariyah', 'النورية', 'Al Madinah Al Munawarah|طريق المدينة المنورة', "15", ["motorway" "trunk" "primary"], 'high', true, 'on the boundary by crossing rule'), ...
    mk('laith', 'Al-Laith', 'الليث', 'Al Laith Road|طريق الليث', "", ["trunk"], 'high', false, 'project lead: this checkpoint is far from the boundary -> outside the coverage') ];
A.cams_per_checkpoint     = 16;     % ASSUMED, source-based: 16 cameras at Al-Shumaisi [okaz_shumaisi]
A.n_interdiction          = 32;     % [ajel_32points]
A.allow_filler            = true;   % true: complete the 32 points with filler sites near roads; false: only real crossings (23 with the current data)
A.cams_per_interdiction   = 4;     % PLACEHOLDER: not published; sensitivity 2 and 8
A.cams_per_interdiction_range = [2 8];
A.interdiction_road_classes = ["secondary" "tertiary" "primary" "trunk" "motorway" "motorway_link" "trunk_link" "primary_link"];  % ASSUMED: lesser roads first (see place_existing_assets)
A.site_merge_m            = 1500;   % ASSUMED (DAS-map): crossings closer than this are one site
A.interdiction_merge_m    = 500;    % ASSUMED: interdiction crossings closer than this are one point (lesser roads are dense; 1.5 km left too few)
A.site_near_boundary_m    = 2000;   % ASSUMED: a site farther than this from the boundary (offset along the road) is out of the coverage
A.footprint_m             = v.Cov_CCTV_m;   % ASSUMED: all cameras of one site watch the same lanes -> ONE Cov_CCTV stretch of boundary per site
A.footprint_range_x       = [1 4];  % sensitivity multipliers of the footprint
% Drone / patrol scenarios (numbers not published). Drones are detection assets; patrols are RESPONSE / VERIFICATION only
% (no Pd / Pc in the table) and do NOT enter the AD0 constraint.
A.scenarios = struct('name', {'low', 'medium', 'high'}, 'N_drone', {3, 6, 12}, 'N_patrol', {5, 15, 30});
A.scenario_tag = 'ASSUMED (counts not published; low drone count = the 3 of the table row N_drone_avail)';
A.patrol_role  = 'response/verification (not a detection layer)';

%% ---- 4. PLACEHOLDERs: values that have NO source. Edit HERE only. Each one is swept in the sensitivity study. ---
PH.C_shelter  = struct('value', num('C_shelter'), 'range', [0 300000], 'why', 'MISSING: no cabin cost in any source; the table row C_shelter holds 0 = not costed yet (this under-states C_total)');
% C_fiber has a number in the table but the reviewers flag it as extremely doubtful and no Saudi figure is published:
% kept as a PLACEHOLDER with sensitivity x0.5 and x2 (decision of 21 Nov).
PH.C_fiber_per_km = struct('value', num('C_fiber'), 'range', num('C_fiber') * [0.5 2], ...
                           'why', 'table value 60,700 SAR/km, no published Saudi figure, flagged extremely doubtful; sensitivity x0.5 and x2');
fn = fieldnames(PH);
for k = 1:numel(fn)
    put(fn{k}, PH.(fn{k}).value, 'PLACEHOLDER', PH.(fn{k}).why);
    rng.(fn{k}) = PH.(fn{k}).range;
end
%% ---- 4b. source-based values, read from the table (decisions of 21 Nov) ------------------------------------------
% Bib keys: zeng2024, liu2016, wang2024, khan_uav_thermal, dji_dock3_specs, gsma_coolsure (additions2.bib).
put('AC0', num('AC0')/100, 'TABLE', 'AC0 = 98% (project target). Main constraint: Pc_DAS >= AC0 (classifier on the DAS signal); whole-system accuracy is an extra result');
put('Pd_DAS', num('Pd_DAS'), 'TABLE', 'Pd_DAS = 0.969 [zeng2024: IDR 96.9%, one disturbance site]; field 100% [liu2016] -> sensitivity up to 1.0; to be replaced by the Monte Carlo');
rng.Pd_DAS = [num('Pd_DAS') 1.0];
pcr = str2double(regexp(strrep(strrep(char(row('Pc_DAS').value), char(8211), ' '), char(8722), ' '), '\d*\.?\d+', 'match'));
assert(numel(pcr) == 2, 'load_params:PcDAS', 'Pc_DAS row must hold a range "low - high".');
put('Pc_DAS', min(pcr), 'TABLE', 'Pc_DAS range 0.983-0.993 [wang2024 via Shao 2025]: 99.3% one disturbance point, 98.3% several; base case = the lower end, both ends are run');
rng.Pc_DAS = [min(pcr) max(pcr)];
put('Pc_drone', num('Pc_drone'), 'TABLE', 'Pc_drone = 0.89 [khan_uav_thermal: YOLOv8s on HIT-UAV, precision 0.891]: a PROXY (precision, not accuracy; no animals)');
rng.Pc_drone = [0.80 0.95];                            % ASSUMED sensitivity range
put('T_charge_min', num('T_charge'), 'TABLE', 'T_charge = 27 min [dji_dock3_specs: 15% to 95% at 25 C]; DJI figure only');
rng.T_charge_min = [27 60];                            % ASSUMED sensitivity range (60 min was the old placeholder)
%% ---- 4c. drones as a RESPONSE / VERIFICATION layer (decision of 22 Nov): response-time parameters --------------------------------
% Drones do not detect. After a DAS alarm a drone from a station within reach verifies the event; detection (AD0) comes from DAS and
% cameras only. A station reaches a cell if the farthest point of the cell is within R_resp = min(Cov_drone, v_drone*(T_resp - T_launch)).
put('v_drone_ms', num('v_drone'), 'TABLE', 'Matrice 4D/4TD max horizontal speed 15 m/s: Normal mode, the only mode allowed with DJI Dock 3 (DJI official specs, key dji_dock3_specs)');
put('T_launch_s', num('T_launch'), 'TABLE', 'dock takeoff time 10 s for DJI Dock 3: SOURCE = reseller page (key advexure_dock3), VERIFY on the DJI official page (not on the DJI specs page)');
put('T_resp_s', num('T_resp'), 'PLACEHOLDER', 'response time within which a drone must reach the cell; PLACEHOLDER linked to T_alert (TBD, Student 1); sensitivity 180-600 s');
rng.T_resp_s = [180 600];
put('A_ver_min', num('A_ver_min'), 'PLACEHOLDER', 'minimum probability that a drone is ready for the verification layer of a Hot cell (one drone = 0.635, two drones at a station = 1.0); PLACEHOLDER, sensitivity 0.8 and 0.95');
rng.A_ver_min = [0.8 0.95];
put('R_resp_m', min(v.Cov_drone_m, v.v_drone_ms * (v.T_resp_s - v.T_launch_s)), 'TABLE-DERIVED', 'R_resp = min(Cov_drone, v_drone*(T_resp - T_launch)); equals the table row R_resp');
assert(abs(v.R_resp_m - num('R_resp')) < 1e-9, 'load_params:Rresp', 'R_resp in the table (%g) differs from min(Cov_drone, v_drone*(T_resp - T_launch)) = %g', num('R_resp'), v.R_resp_m);
put('P_shelter', num('P_shelter'), 'TABLE', 'P_shelter = 170 W [gsma_coolsure: cooling 30-50% of site load -> 73 to 170 W]; upper bound taken for Makkah heat');
rng.P_shelter = [73 170];
lc = str2double(regexp(char(row('lambda_cold').value), '\d+', 'match'));
put('lambda_cold_range', lc, 'TABLE', 'lambda_cold = 1-2 events/day per zone (replaces 0); not used by the optimization (simulation input)');
put('FAR_loss', num('FAR')/100, 'TABLE', 'FAR = 2% as a ratio (1 - precision) [zeng2024 definition]; not used by the optimization');
% Point-Sensor Networks: every value is TBD in the table -> excluded from the base case (no data, no locations).
put('use_PS', false, 'ASSUMED', 'Point-Sensor Networks excluded from the base case: all their values are TBD; hooks kept in the code');
for s = {'Cov_PS','P_PS','Pd_PS','Pc_PS','C_PS'}
    put([s{1} '_value'], num(s{1}), 'PLACEHOLDER', [s{1} ' is TBD in the table (NaN = not available)']);
end

%% ---- 5. derived quantities (formula and its inputs stated) ------------------------------------------------
put('N_DAS_int_full', ceil(v.L_boundary_m / (v.N_ch_active * v.R_DAS_m)), 'TABLE-DERIVED', ...
    'ceil(L_boundary / (N_ch_active * R_DAS)) = 4 (table row N_DAS_int); upper-bound check only, the MILP decides the number');
% P0: the table value (29,100 W) equals the method of the P0 row note: a CCTV-only system covering the same length.
put('P0', num('P0'), 'TABLE', 'P0 = 29,100 W = ceil(L_boundary / Cov_CCTV) x P_CCTV = 1455 x 20 W (CCTV-only system, row P0)');
assert(v.P0 == ceil(v.L_boundary_m / v.Cov_CCTV_m) * v.P_CCTV, 'load_params:P0', 'P0 in the table differs from ceil(L_boundary/Cov_CCTV) x P_CCTV.');
rng.P0 = [0.1 1] * v.P0;
put('A_drone_1', v.T_drone_min / (v.T_drone_min + v.T_charge_min), 'DERIVED-PROPOSED', ...
    'availability of ONE drone = T_drone / (T_drone + T_charge); T_charge is a PLACEHOLDER');

%% ---- 6. modelling options (defaults = the recommendations; the caller may override) ---------------------------
opts = struct();
opts.classification_fusion = 'weighted_vote';  % 'weighted_vote' | 'max' | 'independent_or' (optimistic upper bound)
opts.hot_layers_rule       = 'pointwise';      % each point of a Hot cell must be covered by >= 2 layers
opts.hot_min_layers        = 2;
opts.hot_layer_counting    = 'types';          % kept for compatibility; layers are now: DAS (detection) + verification (camera over the whole cell or drone in reach)
opts.max_drone_units       = 2;                % ASSUMED: at most this many drone stations count for the verification of one cell
opts.ac0_definition        = 'classifier';     % 'classifier': AC0 is a requirement on the DAS classifier (Pc_DAS >= AC0, needs DAS in the cell);
                                               % 'system': whole-system accuracy conditional on detection (reported as an extra result)
opts.relax_cold            = false;           % true: scenario with a relaxed target in Cold cells (decision pending)
opts.drone_time_share      = false;            % true: split a drone's watch time over the cells it serves (sensitivity)

P = struct('v', v, 'tag', tag, 'src', src, 'range', rng, 'raw', raw, 'opts', opts, 'assets', A, 'tsvFile', string(tsvFile));
end

function x = parse_number(s)
% First plain number in the text (unicode minus allowed); NaN for TBD or non-numeric text.
s = strrep(char(s), char(8722), '-');
if isempty(regexp(s, '^\s*-?\d', 'once')), x = NaN; return; end
x = sscanf(s, '%f', 1);
if isempty(x), x = NaN; end
end
