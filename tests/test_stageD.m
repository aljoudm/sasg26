function test_stageD()
c = sasg_config();  S = load(fullfile(c.resDir, 'placement.mat'));  F = S.F;
assert(F.N_IU == 1 && F.N_ch_spare == 2, 'expected 1 interrogator, 2 spare channels');
assert(all(F.chNeedKm <= F.R_DAS_km), 'channel exceeds R_DAS');
assert(abs(F.lead_m / 1e3 + F.chLenKm(1) - F.chNeedKm(1)) < 1e-9, 'lead-in not counted');
assert(abs(sum(F.chLenKm) - F.L_km) < 0.02, 'channels must cover the whole boundary');
fprintf('test_stageD OK: channels %.3f / %.3f km (lead-in %.0f m), sensing points %d\n', F.chNeedKm, F.lead_m, F.N_sensing);
end
