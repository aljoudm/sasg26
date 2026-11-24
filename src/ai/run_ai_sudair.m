function A = run_ai_sudair()
% RUN_AI_SUDAIR  Stage AI. Classifies the four Stage F events (results/das_sudair.mat) with the SAME AI interface full-das used for Makkah:
% third_party/fulldas_ai/src/ai/ai_interface.m (read-only copy, see its PROVENANCE.md). use_real_ai = false: TEMPORARY stub. No new classifier.
%
%   Runs (one fixed seed each, RandStream Threefry seed 1):
%     Pc_0.983          base, mode 'uniform', Pc = 0.983 (file value)      Pc_DAS low end  [SOURCE: wang2024 via Shao 2025]
%     Pc_0.993          base, mode 'uniform', Pc = 0.993                   Pc_DAS high end [SOURCE: wang2024 via Shao 2025]
%     Brno_sensitivity  mode 'confusion_counts' (Brno matrix), labelled "Brno, 4 test recordings, SENSITIVITY"
%   Routing as full-das respond_day: threat class -> ALARM -> camera verification; a 'vehicle' output for the vehicle on the access road ->
%   logged; any other class -> no alarm. The calibration sine is classified but excluded from the alarm logic.
%   True class of the calibration sine = no_event [ASSUMED: a calibration tone is not an activity].
%
%   Outputs: results/ai_sudair.mat (A), results/ai_results.csv, report/ai_results.md. All results SIMULATED.
c = sasg_config();  aiRoot = fullfile(c.root, 'third_party', 'fulldas_ai');
S = run_das_sudair();
type = string({S.tab.type})';  name = string({S.tab.name})';
truth = type;  truth(type == "walk") = "walking";  truth(type == "dig") = "digging";  truth(type == "sine") = "no_event";
event = name;  event(type == "walk") = "Walking = map intruder";  event(type == "vehicle") = "Vehicle = map vehicle (access road)";
onRoad = type == "vehicle";                       % scenario_sudair: the engine vehicle is the map vehicle on an access road
excluded = type == "sine";
seed = 1;
runs = struct('id', {"Pc_0.983", "Pc_0.993", "Brno_sensitivity"}, 'mode', {"uniform", "uniform", "confusion_counts"}, 'Pc', {0.983, 0.993, 0.983}, ...
    'label', {"base: uniform stub, Pc 0.983 (Pc_DAS low end, wang2024 via Shao 2025)", ...
              "base: uniform stub, Pc 0.993 (Pc_DAS high end, wang2024 via Shao 2025)", ...
              "Brno, 4 test recordings, SENSITIVITY (classes missing from the matrix fall back to the uniform stub, Pc 0.983)"});
threatSet = ["walking" "running" "vehicle" "digging" "climbing" "tampering"];     % full-das src/response/respond_day.m
T = table();
for r = 1:numel(runs)
    root = aiRoot;  tmp = "";
    cfg0 = jsondecode(fileread(fullfile(aiRoot, 'config', 'ai_config.json')));
    if abs(runs(r).Pc - cfg0.classifier.Pc) > 1e-12, tmp = temp_root(aiRoot, runs(r).Pc);  root = tmp; end
    [cl, cfg] = call_ai(root, truth, runs(r).mode, seed);
    if tmp ~= "", rmdir(tmp, 's'); end
    assert(~cfg.use_real_ai, 'use_real_ai must stay false (stub)');
    assert(string(cfg.classifier.mode) == runs(r).mode && abs(cfg.classifier.Pc - runs(r).Pc) < 1e-12, 'AI config of run %s not as intended', runs(r).id);
    pred = string(cl.class(:));  conf = cl.confidence(:);
    route = strings(numel(pred), 1);
    for k = 1:numel(pred)
        if excluded(k),                                  route(k) = "excluded (calibration, not in the alarm logic)";
        elseif pred(k) == "vehicle" && onRoad(k),        route(k) = "logged (vehicle on the access road)";
        elseif ismember(pred(k), threatSet),             route(k) = "ALARM -> camera verification";
        else,                                            route(k) = "no alarm (non-threat class)";
        end
    end
    T = [T; table(repmat(runs(r).id, numel(pred), 1), event, truth, pred, round(conf, 2), route, ...
        'VariableNames', {'run', 'event', 'true_class', 'predicted_class', 'confidence', 'route'})]; %#ok<AGROW>
end
A.T = T;  A.runs = runs;  A.seed = seed;  A.base = "Pc_0.983";
A.note = "AI: full-das interface, stub (Pc from literature); real ViT-1D classifier trained/tested on Brno only, not yet connected";
A.label = "SIMULATED";
save(fullfile(c.resDir, 'ai_sudair.mat'), 'A');
writetable(T, fullfile(c.resDir, 'ai_results.csv'));
write_report(c, A);
disp(T);
end

function [cl, cfg] = call_ai(root, truth, mode, seed)
p = fullfile(root, 'src', 'ai');  addpath(p, '-begin');  clear ai_interface
setenv('AI_CLASSIFIER_MODE', char(mode));
c = onCleanup(@() cleanup(p));
cfg = ai_interface('config');
cl = ai_interface('classify_batch', truth, RandStream('Threefry', 'Seed', seed));
end

function cleanup(p)
setenv('AI_CLASSIFIER_MODE', '');  rmpath(p);  clear ai_interface
end

function tmp = temp_root(aiRoot, Pc)
% Temporary copy of the read-only interface with ONLY Pc changed (the copy in third_party is never edited).
tmp = string(tempname);  mkdir(fullfile(tmp, 'src', 'ai'));  mkdir(fullfile(tmp, 'config'));
copyfile(fullfile(aiRoot, 'src', 'ai', 'ai_interface.m'), fullfile(tmp, 'src', 'ai'));
copyfile(fullfile(aiRoot, 'config', 'class_map.yaml'), fullfile(tmp, 'config'));
txt = fileread(fullfile(aiRoot, 'config', 'ai_config.json'));
new = regexprep(txt, '"Pc":\s*[0-9.]+', sprintf('"Pc": %.3f', Pc), 'once');
assert(~strcmp(new, txt), 'Pc field not found in ai_config.json');
fid = fopen(fullfile(tmp, 'config', 'ai_config.json'), 'w');  fwrite(fid, new);  fclose(fid);
end

function write_report(c, A)
L = ai_labels(A);
f = fopen(fullfile(c.root, 'report', 'ai_results.md'), 'w', 'n', 'UTF-8');  w = @(varargin) fprintf(f, varargin{:});
w('# Stage AI: classification of the Sudair events (SIMULATED)\n\n');
w('**%s**\n\n', A.note);
w('Interface: `third_party/fulldas_ai/src/ai/ai_interface.m` (read-only copy of full-das, see its `PROVENANCE.md`), `use_real_ai = false`.\n');
w('Events: the four Stage F events of `results/das_sudair.mat` (simulated, commercial interrogator parameters). Seed: RandStream Threefry %d, one stream per run.\n', A.seed);
w('Pc_DAS 0.983 to 0.993 [SOURCE: wang2024 via Shao 2025]; full-das tags it ASSUMED because literature figures from random-window splits are probably optimistic.\n');
w('Routing as full-das `respond_day`: threat class -> ALARM -> camera verification; vehicle on the access road -> logged; the calibration sine is excluded from the alarm logic.\n');
w('The calibration sine is passed with true class `no_event` [ASSUMED]. Confidence values are the stub''s PLACEHOLDER confidence.\n\n');
for r = 1:numel(A.runs)
    w('## %s\n%s\n\n| Event | True class | Predicted class | Confidence | Route |\n| --- | --- | --- | --- | --- |\n', A.runs(r).id, A.runs(r).label);
    S = A.T(A.T.run == A.runs(r).id, :);
    for k = 1:height(S), w('| %s | %s | %s | %.2f | %s |\n', S.event(k), S.true_class(k), S.predicted_class(k), S.confidence(k), S.route(k)); end
    w('\n');
end
w('## Figure labels (from run %s)\n', A.base);
w('| Figure element | Label |\n| --- | --- |\n');
w('| Twin and intruder map, intruder | %s |\n', L.intr);
w('| Twin, vehicle | %s |\n', L.veh);
w('| Intruder map, step 3 | %s |\n', L.step3);
w('| STATUS panel note | %s |\n', L.status);
fclose(f);
end
