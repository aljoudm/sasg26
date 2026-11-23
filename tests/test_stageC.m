function test_stageC()
c = sasg_config();  S = load(fullfile(c.zonesDir, 'zones.mat'));  Z = S.Z;
[Lh, ~, ~] = ring_lengths(readmatrix(c.boundaryCsv));
assert(abs(sum(Z.kmZone) - Lh) < 0.005, 'zone lengths (%.4f) do not sum to L_boundary (%.4f)', sum(Z.kmZone), Lh);
assert(abs(Z.cs - 250) < eps && Z.nZone(3) > 0, 'unexpected cell size / no Hot cell');
T = readtable(fullfile(c.zonesDir, 'cells.csv'));  assert(all(string(T.lambda_cell_mid) == "TBD"), 'lambda must be TBD');
assert(all(ismember(S.rows(:,1)', [100 250 500])), 'sensitivity cell sizes');
fprintf('test_stageC OK: Hot/Neutral/Cold = %.3f/%.3f/%.3f km, sum %.3f vs L_boundary %.3f\n', Z.kmZone(3), Z.kmZone(2), Z.kmZone(1), sum(Z.kmZone), Lh);
end
