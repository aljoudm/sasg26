function import_das_sim(cloneDir, commit, resultsSubdir, outFile)
% IMPORT_DAS_SIM  Import the output of the phi-OTDR simulator (github.com/aljoudm/DAS-Simulation, script main.m,
% default parameters of src/params.m, seed 42) for the DAS-trace panel. Nothing is generated here: the
% activity profile is R.act as saved by main.m in results/results.mat; the detection threshold uses the
% simulator's own rule (das_app.m): median(a) + 8 * 1.4826 * MAD(a).
% resultsSubdir (default 'results' = old import) and outFile (default cfg.simFile). FEBUS import:
%   import_das_sim('<clone>', '<git commit>', 'results_febus', fullfile(<repo>, 'data', 'das_sim', 'das_sim_febus.mat'))
cfg = config();
if nargin < 3 || isempty(resultsSubdir), resultsSubdir = 'results'; end
if nargin < 4 || isempty(outFile), outFile = cfg.simFile; end
S = load(fullfile(cloneDir, resultsSubdir, 'results.mat'));      % P, act_profile [m], z_profile [m], ...
addpath(fullfile(cloneDir, 'src'));  cleanup = onCleanup(@() rmpath(fullfile(cloneDir, 'src')));
ev = define_events(S.P);                                       % names / positions as defined in the repo

z = double(S.z_profile(:));   a = double(S.act_profile(:)) * 1e9;       % nm rms (activity > ~5 Hz)
med = median(a);   thr = med + 8 * 1.4826 * median(abs(a - med));
events = struct('name', {}, 'type', {}, 'z0', {}, 'peak_nm', {});
for i = 1:numel(ev)
    events(i) = struct('name', string(ev(i).name), 'type', string(ev(i).type), 'z0', ev(i).z0, ...
        'peak_nm', max(a(abs(z - ev(i).z0) < 60)));            % same +-60 m window as main.m
end
sim.z = z;   sim.a = a;   sim.thr = thr;   sim.median = med;   sim.events = events;
sim.params = struct('L_m', S.P.L, 'pulse_ns', S.P.tau * 1e9, 'PRF_Hz', S.P.PRF, 'Npulses', S.P.Npulses, 'dz_res_m', S.P.dz_res, ...
    'SNR_dB', S.P.SNR_dB, 'gauge_m', S.P.gauge, 'seed', S.P.seed);
sim.source = struct('repo', 'github.com/aljoudm/DAS-Simulation', 'commit', commit, 'script', 'main.m', 'results_dir', resultsSubdir, ...
    'threshold_rule', 'das_app.m: median(a) + 8*1.4826*MAD(a)');
if ~exist(fileparts(outFile), 'dir'), mkdir(fileparts(outFile)); end
save(outFile, 'sim');
fprintf('Saved %s\n', outFile);
fprintf('DAS sim imported: %d samples over %.1f km, median %.2f nm, threshold %.2f nm\n', numel(z), z(end)/1e3, med, thr);
for i = 1:numel(events), fprintf('  %-26s z0 = %4.0f m  peak %.1f nm\n', events(i).name, events(i).z0, events(i).peak_nm); end
end
