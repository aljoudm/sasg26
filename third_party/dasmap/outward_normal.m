function [nx, ny] = outward_normal(F, i, poly)
% OUTWARD_NORMAL  Unit normal at fibre sample i pointing OUT of the perimeter polygon (local km).
a = max(i - 25, 1);  b = min(i + 25, numel(F.x));
tv = [F.x(b) - F.x(a), F.y(b) - F.y(a)];  tv = tv / norm(tv);
nv = [-tv(2) tv(1)];
if inpolygon(F.x(i) + 1.0*nv(1), F.y(i) + 1.0*nv(2), poly.x, poly.y), nv = -nv; end
nx = nv(1);  ny = nv(2);
end
