function test_stageA()
c = sasg_config();  ring = readmatrix(c.boundaryCsv);
[Lh, Lp, A] = ring_lengths(ring);
assert(abs(A / c.area_pub_km2 - 1) <= c.area_tol, 'area outside +-10%');
assert(abs(Lh - 32.304) < 0.01 && abs(Lp - 32.304) < 0.01, 'L_boundary changed');
T = readtable(c.substationCsv);  assert(any(T.inside_or_touching_plant), 'no substation touching plant');
fprintf('test_stageA OK: A=%.2f km2, L=%.3f km\n', A, Lh);
end
