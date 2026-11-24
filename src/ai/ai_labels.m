function L = ai_labels(A)
% AI_LABELS  Figure labels taken from the Stage AI output (base run, results/ai_sudair.mat), so the twin, the intruder map and the
% STATUS panel always show what the AI interface returned. Also writes results/ai_figure_labels.json (checked by tests/test_stageAI.m).
c = sasg_config();
if nargin < 1
    f = fullfile(c.resDir, 'ai_sudair.mat');
    if ~isfile(f), run_ai_sudair(); end
    A = load(f).A;
end
B = A.T(A.T.run == A.base, :);  arr = char(8594);
iI = find(startsWith(B.event, "Walking"), 1);  iV = find(startsWith(B.event, "Vehicle"), 1);
L.intr  = sprintf('Intruder: detected %s AI: %s (%.2f) %s %s', arr, show(B.predicted_class(iI)), B.confidence(iI), arr, short(B.route(iI)));
L.veh   = sprintf('Vehicle on access road %s AI: %s (%.2f) %s %s', arr, show(B.predicted_class(iV)), B.confidence(iV), arr, short(B.route(iV)));
L.step3 = sprintf('3  AI: %s', show(B.predicted_class(iI)));
L.intr_route = upper(short(B.route(iI)));  L.veh_route = upper(short(B.route(iV)));
L.intr_class = show(B.predicted_class(iI));  L.veh_class = show(B.predicted_class(iV));
L.intr_conf = B.confidence(iI);  L.veh_conf = B.confidence(iV);
Pc = A.runs(strcmp([A.runs.id], A.base)).Pc;
L.status = sprintf('AI: full-das interface (stub, Pc %.3f)', Pc);
fid = fopen(fullfile(c.resDir, 'ai_figure_labels.json'), 'w', 'n', 'UTF-8');  fwrite(fid, jsonencode(L, 'PrettyPrint', true), 'char');  fclose(fid);
end

function s = show(cls)
cls = string(cls);
if ismember(cls, ["walking" "running" "digging" "climbing" "tampering"]), s = sprintf('human (%s)', cls);
elseif cls == "no_event", s = 'no event';
else, s = char(cls);
end
end

function s = short(route)
route = string(route);
if startsWith(route, "ALARM"), s = 'ALARM';
elseif startsWith(route, "logged"), s = 'logged';
elseif startsWith(route, "excluded"), s = 'excluded';
else, s = 'no alarm';
end
end
