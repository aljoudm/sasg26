function m = zone_params()
% ZONE_PARAMS  Zone / risk parameters. Mirrors config/parameters_sasg26.tsv (tags there). DAS-map values reused as METHOD parameters.
m.cell_size = 250;                  % m [ASSUMED: 20-30 km perimeter vs 145 km for DAS-map (1000 m)]
m.cell_size_sens = [100 500];       % m [SIM SETTING: sensitivity]
m.R_hot_sub = 500;                  % m [ASSUMED: standoff around the 380 kV yard; see parameters_sasg26.tsv]
m.cell_risk_pct = 90;               % [ASSUMED: DAS-map choice]
m.zone_k = 2;                       % [ASSUMED: Hot is forced by the substation; remaining cells split Cold/Neutral]
m.zone_kmeans_replicates = 50;      % [SIM SETTING]
m.zone_seed = 20261123;             % [SIM SETTING]
m.zone_smooth_sigma = 6;            % DEM px [ASSUMED: DAS-map design value]
m.min_cell_frac = 0.25;             % [ASSUMED: DAS-map choice]
m.zone_step_m = 5;                  % m [ASSUMED: DAS-map choice]
risk_w = [0.40 0.25];               % [ASSUMED: DAS-map design weights slope, road distance]
m.zone_w = risk_w / sum(risk_w);    % [DERIVED]
m.slope_full_deg = 40;              % [ASSUMED: DAS-map design value]
m.road_full_m = 3000;               % [ASSUMED: DAS-map design value]
m.road_classes = ["motorway" "trunk" "primary" "secondary" "tertiary" "motorway_link" "trunk_link" "primary_link"];
m.lambda = 'TBD';                   % [PLACEHOLDER] no Sudair intrusion-rate source
end
