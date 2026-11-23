function m = map_params(mode)
% MAP_PARAMS  ONE config file for the device / cost / power / map-design values (struct m). Every script reads from here.
%   m = map_params()          values (+ overrides applied, derived values computed)
%   map_params('report')      same, and prints the totals ("<symbol> = TBD (<owner>)" for missing values)
%
% TO UPDATE A VALUE: edit ONLY the overrides block below (NaN = not received yet; a non-NaN value replaces the default).
% Source tags: [FEBUS] [DATASHEET] [DERIVED] [COMPUTED-MAP] [ASSUMED: <source>] [SIM SETTING] [TBD: <owner>]
% Sheet symbols (Google Sheet) are used exactly as named there.
if nargin < 1, mode = ''; end

% ----- Overrides: NaN = not received yet. If set, replaces the value below.
%       (vendor data or teammates' final values) -----
m.C_DAS_int_override = NaN;   m.C_fiber_override = NaN;       % vendor quote / Saudi fibre price
m.R_DAS_override     = NaN;   m.P_DAS_override   = NaN;       % [m], [W]  (vendor data)
m.Pd_DAS_override    = NaN;                                   % owner: DAS-Simulation
m.Pc_DAS_override    = NaN;                                   % owner: Simulation A (DL classifier)
m.C_CCTV_override  = NaN;  m.Cov_CCTV_override  = NaN;  m.P_CCTV_override  = NaN;  m.Pd_CCTV_override = NaN;  m.Pc_CCTV_override = NaN;   % owner: Student 2
m.C_drone_override = NaN;  m.Cov_drone_override = NaN;  m.P_drone_override = NaN;  m.T_drone_override = NaN;  m.Pd_drone_override = NaN;  % owner: Student 2
m.C_PS_override    = NaN;  m.Cov_PS_override    = NaN;  m.P_PS_override    = NaN;  m.Pd_PS_override   = NaN;                            % owner: Student 2 (point sensors)
m.w_k_override = NaN;   % owner: Student 2 (Decision Matrix weights, not used by this repo)
m.cell_size_override = NaN;  m.R_hot_override = NaN;  m.R_cold_override = NaN;   % owner: DAS-map zones (WIP)
m.lambda_hot_override = NaN;  m.lambda_neutral_override = NaN;  m.lambda_cold_override = NaN;                                            % owner: DAS-map zones (WIP)
m.C_DAS_int_EUR_override = NaN;  m.fx_EUR_SAR_override = NaN;   % vendor price [EUR] / exchange rate (update when quoted)
m.P_shelter_override = NaN;                                   % owner: Team (AC power per shelter)
m.C_total_override = NaN;                                                                                                                % owner: team (sum of all components)

% ----- [DATASHEET] FEBUS A1-NEO (datasheet rev. 20260618) -----
m.R_DAS     = 20e3;  % range per channel [m] (20 km option; 70/100 km exist,
                     % 100 km needs LR option, all assume 0.2 dB/km)
m.N_ch_DAS  = 4;     % synchronous channels per interrogator
m.N_ch_active = 2;   % [DERIVED: two directions along the boundary] a site on a linear/closed boundary can serve only two
                     % directions (channel 1 one way, channel 2 the other); channels 3-4 would need lead-in fibre that counts
                     % against R_DAS, so coverage per interrogator = 2 x R_DAS (NOT 4 x R_DAS)
m.N_ch_spare  = m.N_ch_DAS - m.N_ch_active;   % [DERIVED] spare channels (redundancy / possible double coverage in Hot zones); no sensing segment assigned
m.N_DAS_int_extra = 0;  % sites added beyond the formula because the placement assert needed them (compute_fibre.m tells you the value)
m.P_DAS     = 170;   % power per interrogator [W]
m.dz_res    = 10;    % spatial resolution [m] (chosen within 1-50 m [SIM SETTING]; same as DAS-Simulation)
m.dz_samp   = 2;     % channel spacing [m] [SIM SETTING]
m.T_op_max  = 40;    % max operating temperature [degC] -> interrogators must be housed in
                     % air-conditioned shelters; only the cable is in the field

% ----- Cost/price values -----
m.C_DAS_int_EUR = 150000;      % EUR/unit [SHEET: Student 2, from vendor meeting] interrogator price (not in datasheet)
m.fx_EUR_SAR    = 4.24;        % SAR per EUR [ASSUMED: interbank rate 15 Oct 2026; update]
m.C_DAS_int     = m.C_DAS_int_EUR * m.fx_EUR_SAR;   % [DERIVED] SAR/unit (recomputed after the overrides below)
m.C_fiber   = NaN;   % [TBD: Saudi source] fibre cable cost PER KM (formula below uses L in km). NOT taken from the Sheet: the team flagged
                     % the Sheet value as doubtful; stays TBD until a Saudi price is confirmed. SAR/km.

% ----- Lead-in and shelter power -----
m.L_leadin  = 0;     % [ASSUMED: shelter on boundary; edit when site known] lead-in fibre from AC shelter to boundary [m], counted in every channel's fibre length
m.P_shelter = NaN;   % [TBD: AC power per shelter] air-conditioning power per shelter [W]

% ----- Backscatter trace of ONE channel (analytic; same model as DAS-Simulation) -----
m.P0         = 0.1;     % [ASSUMED: Thevenaz 2025] launched peak power [W]
m.R_bs_dB    = -82;     % [ASSUMED: Corning SMF-28 Ultra PI-1424] Rayleigh backscatter coefficient [dB] (for a 1 ns pulse)
m.n_g        = 1.4682;  % [ASSUMED: Corning SMF-28 Ultra] group index
m.c_light    = 299792458;   % [m/s] speed of light
m.alpha_dB_km = 0.2;    % [DATASHEET] FEBUS A1-NEO fibre loss assumed by the range spec [dB/km]
m.tau        = 2 * m.n_g * m.dz_res / m.c_light;   % [DERIVED] pulse width [s] = 2 n_g dz_res / c  (~97.9 ns at 10 m)

% ----- Values owned by others (not yet received): [TBD: owner] -----
m.Pd_DAS = NaN;  m.Pc_DAS = NaN;                                                                  % [TBD: DAS-Simulation] / [TBD: Simulation A (DL classifier)]
% --- values taken from the team Sheet (Sheet status kept in the comment) ---
m.Cov_CCTV  = 100;     % m        [SHEET: Student 2] (the figure's illustrative 1.4 km camera wedge, cam_range_km, is a separate design value)
m.C_CCTV    = 1900.90; % SAR/unit [SHEET: Student 2]
m.P_CCTV    = 20;      % W/unit   [SHEET: Student 2]
m.Pd_CCTV   = 0.909;   m.Pc_CCTV = 0.85;   % [SHEET: Student 2]
m.Cov_drone = 11e3;    % m radius [SHEET: Student 2, proposal] avg DJI Dock 3 / Skydio Dock
m.T_drone   = 47;      % min      [SHEET: Student 2, proposal]
m.C_drone   = 148887;  % SAR/unit [SHEET: Student 2, proposal]
m.P_drone   = 1500;    % W/unit   [SHEET: Student 2, proposal]
m.Pd_drone  = 0.885;   % [SHEET: Student 2, proposal]
m.AD0 = 0.98;  m.AC0 = 0.98;   % [SHEET: project target, approved] detection / classification targets
% NOT taken from the Sheet (left TBD): C_fiber (flagged doubtful by the team); FAR (two conflicting Sheet entries); Sheet f_s = 100 kHz
% (a pulse-repetition rate, different quantity from our 51 MHz spatial sampling); point-sensor values (TBD).
m.C_PS = NaN;    m.Cov_PS = NaN;    m.P_PS = NaN;    m.Pd_PS = NaN;                               % [TBD: Student 2]
% NOTE: w_k (Sheet: Decision Matrix weights, Acc 35 / Cov 25 / Env 15 / Cost 10 / Pwr 10 / Priv 5 %) is NOT used by this repo (no zone
% weighting here) and must not be used anywhere in the code. It only appears in sheet_values.csv; the value is owned by Student 2.
m.w_k = NaN;   % [NOT USED IN THIS REPO: Student 2] Decision Matrix weights, see the note above
m.R_hot = NaN;  m.R_cold = NaN;   % [COMPUTED-ZONES] output of main_zones.m (k-means thresholds on cell risk), see results_zones/; not an input
m.lambda_hot_range     = [11 20];  % events/day per ZONE [SHEET: team assumption]
m.lambda_neutral_range = [8 10];   % events/day per ZONE [SHEET: team assumption]
m.lambda_cold_range    = [0 0];    % events/day per ZONE [SHEET: team assumption]  (0 -> Cold cells never get simulated intrusions: WARNING in main_zones)
m.lambda_hot = mean(m.lambda_hot_range);  m.lambda_neutral = mean(m.lambda_neutral_range);  m.lambda_cold = mean(m.lambda_cold_range);   % [DERIVED] mid of the range, events/day per zone

% ----- Zones (cell classification, main_zones.m) -----
m.cell_size      = 1e3;   % m [CHOSEN: >= Cov_CCTV (100 m -> ~10 cameras/cell), >> DAS resolution (10 m); drones (11 km radius) are a
                          %  SHARED resource across many cells, not per cell]
m.cell_size_sens = [500 1000 2000];   % m [CHOSEN: sensitivity runs]
m.cell_risk_pct  = 90;    % [CHOSEN: the intruder picks the easiest point; P90 of the 30 m DEM-grid risk values in the cell is robust to single outliers]
m.zone_k         = 3;     % [CHOSEN: Cold / Neutral / Hot] k-means clusters on cell risk
m.zone_kmeans_replicates = 50;   % [CHOSEN] k-means replicates
m.zone_seed      = 20261101;     % [SIM SETTING] fixed seed (same as cfg.seed)
m.zone_smooth_sigma = 6;   % DEM pixels [ASSUMED: design] Gaussian smoothing of the risk grid, same as the figure's risk (compute_risk.m)
m.min_cell_frac = 0.25;  % [CHOSEN] a cell whose boundary length is < min_cell_frac * cell_size is merged into the neighbour that continues the boundary (the one with the longer boundary share)
m.zone_step_m    = 5;     % m [CHOSEN] boundary densification step for length-per-cell accounting
m.C_total = NaN;                                                                                  % [TBD: team] needs all component costs

% ----- Fibre / geometry design (moved unchanged from config.m except where noted) -----
m.slack_factor  = 1.00;   % cable length / geometric length [ASSUMED: none added]
m.densify_step  = 20;     % polyline densification step [m] [ASSUMED: geometry/display; kept at the old 20 m so that all
                          % other computed results stay unchanged; independent of dz_res]

% ----- Risk score (DESIGN ASSUMPTIONS): risk = w1*slope + w2*blind + w3*road distance -----
m.risk_w          = [0.40 0.35 0.25];  % [ASSUMED: design]  (slope, blind spot, road distance) -- NOT the Sheet symbol w_k
m.zone_w_raw     = m.risk_w([1 3]);   % [ASSUMED: design; to be replaced by Student 3 Risk Matrix] slope and road-distance weights (CCTV/blind term dropped)
m.zone_w         = m.zone_w_raw / sum(m.zone_w_raw);   % [DERIVED] renormalised to sum 1 (slope, road distance); intrinsic risk only: camera placement is an
                          %  optimisation OUTPUT, so using the CCTV visibility term for zoning would be circular
m.slope_full_deg  = 40;     % [ASSUMED: design] slope at which the slope term saturates [deg]
m.road_full_m     = 3000;   % [ASSUMED: design] road distance at which the road term saturates [m]
m.corridor_km     = 2.0;    % [ASSUMED: design] risk corridor each side of the fibre [km]
m.cam_range_km    = 1.4;    % [ASSUMED: ILLUSTRATIVE] CCTV useful range [km]  (Sheet Cov_CCTV is TBD: Student 2)
m.cam_fov_deg     = 100;    % [ASSUMED: ILLUSTRATIVE] CCTV horizontal field of view [deg]
m.cam_mast_m      = 8;      % [ASSUMED: ILLUSTRATIVE] camera height above ground [m]
m.target_m        = 1.7;    % [ASSUMED: design] target (person) height for the viewshed [m]
m.risk_show_from  = 0.30;   % [ASSUMED: design] risk below this is transparent in the overlay [-]

% ----- Illustrative scenario counts (design elements, not real sites) -----
m.n_CCTV = 16;  m.n_patrol = 5;  m.n_UAV = 3;               % [ASSUMED: ILLUSTRATIVE]
m.entry_merge_km   = 1.5;   % [ASSUMED: design] road entry points closer than this are merged [km]   (was hard-coded in compute_assets.m)
m.cctv_road_km     = 0.5;   % [ASSUMED: design] extra CCTV only within this distance of a road [km]    (was hard-coded in compute_assets.m)
m.patrol_band_km   = [0.4 1.6];  % [ASSUMED: design] patrol points this far from the fibre [km]     (was hard-coded in compute_assets.m)
m.hajj_pilgrims_2026 = 1707301;  % [ASSUMED: GASTAT Hajj Statistics Report 1447H, a published fact]

% ----- [COMPUTED-MAP] -----
m = apply_overrides(m);
if isnan(m.C_DAS_int_override), m.C_DAS_int = m.C_DAS_int_EUR * m.fx_EUR_SAR; end   % [DERIVED] SAR/unit
root = fileparts(mfilename('fullpath'));
m.L_boundary_source = fullfile(root, 'data', 'boundary_perimeter.csv');   % [COMPUTED-MAP] OSM Haram + Holy Sites union
if ~isfile(m.L_boundary_source), m.L_boundary_source = fullfile(root, 'data', 'boundary_haram_osm.csv'); end
m.L_boundary  = ring_length_m(m.L_boundary_source);          % [m] haversine sum, R = 6371008.8 m (same method as compute_fibre.m)
m.L_fibre     = m.L_boundary * m.slack_factor;               % [m] = L_boundary while slack_factor = 1.00
m.N_DAS_int   = ceil(m.L_fibre / (m.N_ch_active * m.R_DAS)) + m.N_DAS_int_extra;   % [DERIVED] number of interrogators
m.P_DAS_total = m.N_DAS_int * m.P_DAS;                       % [DERIVED] [W]
% P_total = P_DAS_total + N_DAS_int * P_shelter  (shelter AC power TBD -> reported as incomplete, never a silent NaN)
m.P_total_known    = m.P_DAS_total + (~isnan(m.P_shelter)) * m.N_DAS_int * max(m.P_shelter, 0);
m.P_total_missing  = {};  if isnan(m.P_shelter), m.P_total_missing = {'P_shelter'}; end
m.P_total_complete = isempty(m.P_total_missing);
m.P_total          = m.P_total_known;  if ~m.P_total_complete, m.P_total = NaN; end
% Cost: C_DAS_total = N_DAS_int*C_DAS_int + (L/1e3)*C_fiber ; C_DAS_int per unit, C_fiber per KM (L converted m -> km).
terms = {'C_DAS_int', m.N_DAS_int * m.C_DAS_int; 'C_fiber', (m.L_fibre / 1e3) * m.C_fiber};
okT = ~isnan(cell2mat(terms(:, 2)));
m.C_DAS_known    = sum(cell2mat(terms(okT, 2)));             % (a) all KNOWN terms (partial sum while terms are missing)
m.C_DAS_missing  = terms(~okT, 1)';                          % (b) symbols still missing
m.C_DAS_complete = all(okT);
m.C_DAS_total    = m.C_DAS_known;  if ~m.C_DAS_complete, m.C_DAS_total = NaN; end   % NaN only when incomplete; use C_DAS_known / _missing to report

if strcmp(mode, 'report'), print_report(m); end
end

% =====================================================================================
function m = apply_overrides(m)
fn = fieldnames(m);
for i = 1:numel(fn)
    if endsWith(fn{i}, '_override')
        base = extractBefore(fn{i}, strlength(fn{i}) - 8);
        if isfield(m, base) && ~isnan(m.(fn{i})), m.(base) = m.(fn{i}); end
    end
end
end

function L = ring_length_m(csv)
ring = readmatrix(csv);
if norm(ring(1,:) - ring(end,:)) > 1e-9, ring(end+1,:) = ring(1,:); end
R = 6371008.8;  a = ring(1:end-1,:);  b = ring(2:end,:);
dlat = deg2rad(b(:,1) - a(:,1));  dlon = deg2rad(b(:,2) - a(:,2));
h = sin(dlat/2).^2 + cosd(a(:,1)) .* cosd(b(:,1)) .* sin(dlon/2).^2;
L = sum(2 * R * asin(min(1, sqrt(h))));
end

function print_report(m)
owner = struct('C_DAS_int', 'vendor quote', 'C_fiber', 'Saudi source');
fprintf('--- map_params: FEBUS A1-NEO ---\n');
fprintf('L_boundary    = %.1f m (%.3f km)   [COMPUTED-MAP, %s]\n', m.L_boundary, m.L_boundary / 1e3, m.L_boundary_source);
fprintf('N_DAS_int     = %d   = ceil(L / (N_ch_active x R_DAS)) + %d extra = ceil(%.3f / (%d x %.0f km)) + %d\n', m.N_DAS_int, m.N_DAS_int_extra, m.L_fibre / 1e3, m.N_ch_active, m.R_DAS / 1e3, m.N_DAS_int_extra);
fprintf('Channels        : %d per interrogator = %d active (one per direction) + %d spare\n', m.N_ch_DAS, m.N_ch_active, m.N_ch_spare);
fprintf('P_DAS_total   = %g W   (%d x %g W)\n', m.P_DAS_total, m.N_DAS_int, m.P_DAS);
if isnan(m.P_shelter), fprintf('P_shelter = TBD (AC power per shelter)\n'); else, fprintf('P_shelter = %g W\n', m.P_shelter); end
if m.P_total_complete, fprintf('P_total (a) all terms            : %g W\n', m.P_total_known);
else, fprintf('P_total (a) known terms only     : %g W   (P_DAS_total only)\n', m.P_total_known); end
if m.P_total_complete, fprintf('P_total (b) missing terms        : none\n');
else, fprintf('P_total (b) missing terms        : %s  -> total INCOMPLETE\n', strjoin(m.P_total_missing, ', ')); end
P1 = backscatter_power(m, 0);  P2 = backscatter_power(m, 20e3);
fprintf('Backscatter P_bs (tau = %.1f ns): %.1f nW at z = 0, %.1f nW at 20 km  [sanity: ~62 / ~10 nW]\n', m.tau * 1e9, P1 * 1e9, P2 * 1e9);
for s = {'C_DAS_int', 'C_fiber'}
    if isnan(m.(s{1})), fprintf('%s = TBD (%s)\n', s{1}, owner.(s{1})); else, fprintf('%s = %g\n', s{1}, m.(s{1})); end
end
fprintf('C_DAS_total (a) known terms only : %g   (SAR; fibre unit = per km)\n', m.C_DAS_known);
if m.C_DAS_complete, fprintf('C_DAS_total (b) missing terms    : none\n');
else, fprintf('C_DAS_total (b) missing terms    : %s  -> total INCOMPLETE\n', strjoin(m.C_DAS_missing, ', ')); end
end
