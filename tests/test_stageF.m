function test_stageF()
c = sasg_config();  S = load(fullfile(c.resDir, 'das_sudair.mat')).S;
F = load(fullfile(c.resDir, 'placement.mat')).F;
assert(abs(S.P.L_m - round(F.longestChannelKm * 1e3)) < 1, 'engine length != longest channel');
assert(all([S.tab.detected]), 'an event is not detected');
assert(all([S.tab.pos_err_m] < 10), 'position error > 10 m');
fprintf('test_stageF OK: L = %d m, max pos err %.1f m, min corr %.3f\n', S.P.L_m, max([S.tab.pos_err_m]), min([S.tab.corr]));
end
