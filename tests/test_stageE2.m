function test_stageE2()
c = sasg_config();  info = imfinfo(fullfile(c.figDir, 'intruder_map.png'));  r = info.Width / info.Height;
assert(abs(r - 1.74) < 0.03, 'aspect %.3f', r);
rg = readtable('C:\Users\aljou\OneDrive\Desktop\full das\results\reid\reid_grid.csv', 'TextType', 'string');
sel = rg.camera_source == "fixed" & rg.spacing_m == 20 & rg.pairs_share == 0 & rg.position_error_m == 1 & rg.clock_offset_s == 0.2 & string(rg.crossing) == "False" & rg.camera_dropout == 0;
assert(nnz(sel) == 1 && abs(rg.person_link_acc(sel) - 0.9992) < 1e-9 && abs(rg.person_link_rate(sel) - 0.9298) < 1e-9, 'reid row mismatch');
fprintf('test_stageE2 OK: aspect %.3f, reid row acc %.4f rate %.4f\n', r, rg.person_link_acc(sel), rg.person_link_rate(sel));
end
