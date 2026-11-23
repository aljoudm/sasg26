% MAIN_STATIC  Static 3D digital-twin figure in BOTH themes (cfg.renderThemes) from ONE scene.
% Status goes to the console only. Outputs: out/digital_twin_light.png, out/digital_twin_dark.png.
here = fileparts(mfilename('fullpath'));
addpath(here, fullfile(here, 'data'));
cfg = config();
if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end
fetch_boundary_osm();  build_perimeter();  prepare_terrain();  fetch_roads_osm();
if ~isfile(cfg.simFile), error('Run data/import_das_sim.m first (phi-OTDR simulator output, see SOURCES.md).'); end
scene = build_scene(cfg);   F = scene.fibre;

fprintf('Perimeter       : %s\n', F.source);
fprintf('Fibre length L  : %.1f km (SLACK_FACTOR=%.2f)   area %.0f km^2\n', F.L_km, cfg.SLACK_FACTOR, F.area_km2);
fprintf('N_IU            : %d (R_ch=%g km, %d active + %d spare of %d channels), %.1f km of boundary per IU; sensing points %d at %g m (channel samples %d at %g m)\n', ...
    F.N_IU, cfg.R_CH_KM, cfg.N_CH_ACTIVE, cfg.m.N_ch_spare, cfg.N_CH, F.iuSpanKm, F.N_sensing, cfg.SPATIAL_RES_M, F.N_samples, cfg.CH_SPACING_M);
fprintf('Segments        : %d sensing channels, segment %.2f-%.2f km, lead-in %.2f km, MAX channel fibre %.2f km, min margin %.2f km (R_DAS %g km, assert passed)\n', ...
    F.nSeg, min(F.segLenKm), max(F.segLenKm), max(F.segFeederKm), max(F.segNeedKm), min(F.segMarginKm), cfg.R_CH_KM);
sm = scene.sim;
fprintf('Simulation      : %s @ %s (%s), %.1f km fibre, pulse %.1f ns, dz %g m; section laid on channel %d (%.2f km)\n', sm.source.repo, sm.source.commit(1:7), sm.source.results_dir, sm.params.L_m/1e3, sm.params.pulse_ns, sm.params.dz_res_m, scene.events.channel, scene.events.secLen);
fprintf('Threshold       : %.2f nm over the channel (full 20 km profile: %.2f nm); median %.2f nm\n', sm.thr, sm.thr_full, sm.median);
for e = sm.events, fprintf('  %-26s z0 = %5.0f m  peak %5.2f nm  %s\n', e.name, e.z0, e.peak_nm, ternary_(e.peak_nm > sm.thr, 'above threshold', 'BELOW threshold')); end
map_params('report');
export_sheet_values(cfg.m, cfg.outDir);
plot_placement(cfg, scene.fibre);
for th = cfg.renderThemes
    [~, scene] = render_figure(scene, char(th));      % scene carries the cached inset calibration to the next theme
end

function s = ternary_(c, a, b)
if c, s = a; else, s = b; end
end
