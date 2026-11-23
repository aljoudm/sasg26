function acc = fuse_classification(pc, mode)
% FUSE_CLASSIFICATION  Accuracy of the fused classification of independent sensors that ALL detected the event.
%
%   acc = fuse_classification(pc, mode)
%     pc   accuracies of the sensors that detected the event (vector in (0,1)); a binary decision (human / non-human),
%          each sensor correct with probability pc(j) whatever the true class (symmetric), errors independent
%     mode 'weighted_vote'  (default, used by the model) Bayes-optimal weighted vote, weight ln(pc/(1-pc)); ties count 1/2
%          'max'            only the most accurate sensor is used (no fusion gain; conservative)
%          'independent_or' 1 - prod(1 - pc): "at least one sensor is right" - NOT a valid classifier (the system cannot know
%                           which sensor is right); kept only as an optimistic upper bound for the report
%
% Detection and classification combine differently. Detection succeeds if ANY sensor detects, so 1 - prod(1 - p) is valid.
% A classification is a decision: when sensors disagree the system must pick one label, and a vote can only be right when the
% majority (weighted) is right.
if nargin < 2, mode = 'weighted_vote'; end
pc = pc(:)';   n = numel(pc);
if n == 0, acc = NaN; return; end
switch mode
    case 'max',            acc = max(pc);
    case 'independent_or', acc = 1 - prod(1 - pc);
    case 'weighted_vote'
        if n == 1, acc = pc; return; end
        w = log(pc ./ (1 - pc));   acc = 0;
        for m = 0:2^n - 1                                   % every combination of right / wrong sensors
            ok = bitget(m, 1:n) == 1;   pr = prod(pc(ok)) * prod(1 - pc(~ok));
            s = sum(w(ok)) - sum(w(~ok));                   % >0: the weighted vote is right, 0: tie
            if s > 1e-12, acc = acc + pr; elseif abs(s) <= 1e-12, acc = acc + pr / 2; end
        end
    otherwise, error('fuse_classification:mode', 'Unknown fusion mode %s', mode);
end
end
