function vp = sasg_viz_params()
% SASG_VIZ_PARAMS  Display-only choices of the restyled twin. Every value is tagged [ASSUMED: display only] in config/parameters_sasg26.tsv.
vp.VERT_EXAG = 4;          % vertical exaggeration (site is flat: 687-771 m)
vp.sun_az = 315;  vp.sun_el = 25;   % hillshade sun: north-west, low
vp.blend_w = 0.9;          % multiplicative blend weight of the hillshade into the Esri texture
vp.dem_smooth_px = 1;      % DEM smoothing before shading [px]
vp.haze_max = 0.40;  vp.haze_col = [0.86 0.83 0.78];   % atmospheric fade toward the far (north) edge
vp.imgMperPx = 2.0;        % hi-res plant imagery [m/px]
vp.contour_m = 10;         % contour interval [m]
vp.contour_label = 3;      % number of labelled contours
vp.plant_blur_px = 0.8;    % light blur of the 2 m/px plant imagery to limit moire from panel rows [px]
vp.band_km = 0.05;  vp.band_alpha = 0.35;   % zone band: +-50 m each side of the fibre
vp.feather_m = 75;   % feather of the hi-res plant texture over the base texture
vp.risk_alpha_max = 0.25;   % risk glow outside the fence only         % zone band width beside the fibre [km, display]
vp.risk_corridor_km = 0.5; % risk glow corridor around the fibre [km, display]
vp.pulseLenKm = 0.2;  vp.pulseSpacingKm = 3;  vp.pulsePhase = 0.45;   % light pulses scaled from DAS-map (4.5 / 15 km)
vp.fibreLift = 0.006;  vp.glowDilate_m = 300;   % lift above the terrain [km, display]; display widening of the energy peak [m]
end
