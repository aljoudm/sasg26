function S = run_das_sudair(redo)
% RUN_DAS_SUDAIR  Stage F. DAS-Simulation engine (third_party/das_engine, 3a8862b, FEBUS A1-NEO parameters), unchanged, with the
% fibre length set to the longest Sudair channel (lead-in + sensing, from results/placement.mat). Events = engine defaults:
% calibration sine, walking, digging, vehicle (define_events.m). Fence climbing: no engine model -> future work, not invented.
% Results are labelled "simulated, FEBUS A1-NEO parameters". Saves results/das_sudair.mat (small; the waterfall is not stored).
if nargin < 1, redo = false; end
c = sasg_config();  out = fullfile(c.resDir, 'das_sudair.mat');
if isfile(out) && ~redo, S = load(out); S = S.S; return; end
addpath(fullfile(c.root, 'third_party', 'das_engine'));
F = load(fullfile(c.resDir, 'placement.mat')).F;
L = round(F.longestChannelKm * 1e3);                                  % m  [DERIVED: longest Sudair channel]
P = params(struct('L', L));
fprintf('Sudair channel L = %d m, PRF %.0f Hz, Npulses %d, Nz %d\n', L, P.PRF, P.Npulses, P.Nz);
Fm = fiber_model(P);  ev = define_events(P);
W = simulate_waterfall(P, Fm, ev);
Dt = detector(P, W, 'coherent');  clear W
R = process_das(P, Dt);  clear Dt
z = double(R.z(:));  act = double(R.act(:)) * 1e9;                    % nm
med = median(act);  thr = med + 8 * 1.4826 * median(abs(act - med)); % same rule as DAS-Simulation das_app.m
tab = struct('name', {}, 'type', {}, 'z0', {}, 'z_est', {}, 'pos_err_m', {}, 'amp_ratio', {}, 'corr', {}, 'peak_nm', {}, 'detected', {});
TS = cell(numel(ev), 1);
for i = 1:numel(ev)
    win = abs(z - ev(i).z0) <= 150;  [pk, k] = max(act .* win);  zE = z(k);
    j = find(abs(z - zE) == min(abs(z - zE)), 1);
    rec = double(R.dL(j, :));  tru = ev(i).dL(:)';  rec = rec - mean(rec);  tru = tru - mean(tru);
    cc = corrcoef(rec, tru);  TS{i} = [tru; rec];
    tab(i) = struct('name', string(ev(i).name), 'type', string(ev(i).type), 'z0', ev(i).z0, 'z_est', zE, 'pos_err_m', abs(zE - ev(i).z0), ...
        'amp_ratio', rms(rec) / rms(tru), 'corr', abs(cc(1, 2)), 'peak_nm', pk, 'detected', pk > thr);
end
S.tab = tab;  S.z = z;  S.act = act;  S.thr = thr;  S.median = med;  S.t = P.t_slow(:)';  S.TS = TS;
S.P = struct('L_m', L, 'PRF_Hz', P.PRF, 'Npulses', P.Npulses, 'Nz', P.Nz, 'dz_res_m', P.dz_res, 'gauge_m', P.gauge, 'tau_ns', P.tau * 1e9, 'seed', P.seed, 'SNR_dB', P.SNR_dB);
% waterfall for the figure: rms of the recovered local elongation dL in 100-pulse time blocks (aliasing-free), max over 10 gauge-samples in z
nb = 100;  nT = floor(P.Npulses / nb);  nz = floor(numel(z) / 10);
Q = zeros(nz, nT, 'single');
for b = 1:nT
    blk = R.dL(1:nz * 10, (b - 1) * nb + (1:nb));  blk = blk - mean(blk, 2);
    q = sqrt(mean(blk .^ 2, 2));  Q(:, b) = max(reshape(q, 10, nz), [], 1)';
end
S.WF = Q * 1e9;  S.WFz = z(5:10:nz * 10);  S.WFt = ((1:nT) - 0.5) * nb / P.PRF;
S.label = 'simulated, FEBUS A1-NEO parameters';
if ~exist(c.resDir, 'dir'), mkdir(c.resDir); end
save(out, 'S');
T = struct2table(tab);  writetable(T, fullfile(c.resDir, 'das_recovered_events.csv'));
disp(T(:, {'name', 'z0', 'z_est', 'pos_err_m', 'amp_ratio', 'corr', 'detected'}));
fprintf('threshold %.2f nm (median %.2f)\n', thr, med);
end
