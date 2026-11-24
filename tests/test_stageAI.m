function test_stageAI()
% TEST_STAGEAI  Stage AI: the table exists and is labelled, the read-only interface copy is the stub, and the figure labels match ai_results.md.
c = sasg_config();
md = fullfile(c.root, 'report', 'ai_results.md');  assert(isfile(md), 'report/ai_results.md missing (run run_ai_sudair)');
txt = string(fileread(md));
A = load(fullfile(c.resDir, 'ai_sudair.mat')).A;
assert(height(A.T) == 3 * 4 && numel(unique(A.T.run)) == 3, 'expected 3 runs x 4 events');
assert(contains(txt, A.note) && contains(txt, "Brno, 4 test recordings, SENSITIVITY") && contains(txt, "SIMULATED"), 'report labels missing');
cfg = jsondecode(fileread(fullfile(c.root, 'third_party', 'fulldas_ai', 'config', 'ai_config.json')));
assert(~cfg.use_real_ai && cfg.classifier.mode == "uniform" && abs(cfg.classifier.Pc - 0.983) < 1e-12, 'third_party copy of ai_config.json changed');
assert(isfile(fullfile(c.root, 'third_party', 'fulldas_ai', 'PROVENANCE.md')), 'PROVENANCE.md missing');
% every row of the table is in the report
for k = 1:height(A.T)
    row = sprintf('| %s | %s | %s | %.2f | %s |', A.T.event(k), A.T.true_class(k), A.T.predicted_class(k), A.T.confidence(k), A.T.route(k));
    assert(contains(txt, row), 'row missing in ai_results.md: %s', row);
end
% labels used by the figures = labels written in the report, and they carry the base run's class and confidence
L = ai_labels(A);  J = jsondecode(fileread(fullfile(c.resDir, 'ai_figure_labels.json')));
for f = ["intr" "veh" "step3" "status"]
    assert(contains(txt, string(L.(f))), 'figure label %s not in ai_results.md', f);
    assert(string(J.(f)) == string(L.(f)), 'ai_figure_labels.json out of date (%s)', f);
end
B = A.T(A.T.run == A.base, :);  w = B(startsWith(B.event, "Walking"), :);
assert(contains(string(L.intr), sprintf('(%.2f)', w.confidence)), 'intruder label confidence != table');
% the renderers take their labels from ai_labels and no hard-coded class is left
for f = ["src/viz/render_twin_sudair.m" "src/viz/draw_status_sudair.m" "src/viz/draw_trace_sudair.m" "src/viz/render_intruder_map.m"]
    s = string(fileread(fullfile(c.root, f)));
    assert(contains(s, "ai_labels()"), '%s does not use ai_labels', f);
    assert(~contains(s, "' human '"), '%s still has a hard-coded class', f);
end
% figures rendered after the AI output
t0 = dir(fullfile(c.resDir, 'ai_sudair.mat')).datenum;
for f = ["twin3d.png" "twin3d_panels.png" "intruder_map.png"]
    d = dir(fullfile(c.figDir, f));  assert(~isempty(d) && d.datenum >= t0, '%s not re-rendered after the AI stage', f);
end
fprintf('test_stageAI OK: %d rows, intruder label "%s"\n', height(A.T), L.intr);
end
