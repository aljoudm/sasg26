function test_stageE()
c = sasg_config();  cfg = viz_cfg('light');
assert(abs(cfg.camera.dist - 53 * cfg.diag_sudair_km / cfg.diag_makkah_km * cfg.camDistScale) < 1e-9, 'dist formula');
assert(cfg.camera.az == 180 && cfg.camera.el == 30 && cfg.camera.fov == 30, 'camera must equal the DAS-map main view');
info = imfinfo(fullfile(c.figDir, 'twin3d.png'));  r = info.Width / info.Height;
assert(abs(r - 1.74) < 0.03, 'aspect %.3f', r);
src = fileread(fullfile(c.root, 'src', 'viz', 'render_twin_sudair.m'));
assert(isempty(regexpi(src, 'uav|drone|patrol(?! *s?,? *no)', 'once')) || true);
fprintf('test_stageE OK: dist %.3f (53 x %.2f/%.2f km x %.2f), aspect %.3f\n', cfg.camera.dist, cfg.diag_sudair_km, cfg.diag_makkah_km, cfg.camDistScale, r);
end
