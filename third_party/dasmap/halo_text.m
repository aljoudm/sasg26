function h = halo_text(ax, x, y, z, str, style, color, scene, group, role)
% HALO_TEXT  Clean 3D label with a thin halo (8 offset copies in the camera plane), no box.
% Halo colour comes from the theme (dark halo in the dark theme, white in the light theme).
if nargin < 9, group = ''; end
if nargin < 10, role = ''; end
cfg = scene.cfg;  th = scene.th;
campos_ = ax.CameraPosition;  tgt = ax.CameraTarget;
dirv = tgt - campos_;   dd = norm(dirv);   dirv = dirv / dd;
rightv = cross(dirv, ax.CameraUpVector);   rightv = rightv / norm(rightv);
upv = cross(rightv, dirv);
figPx = ax.Parent.Position(4) * ax.Position(4);                       % viewport height [px]
pxWorld = 2 * dd * tand(ax.CameraViewAngle / 2) / figPx;              % world units per pixel at target
if strcmp(ax.Projection, 'orthographic') && isfield(scene, 'orthoKmPerPx'), pxWorld = scene.orthoKmPerPx; end
r = 0.8 * pxWorld;                                                    % ~0.8 screen px
for a = (0:7) * pi/4
    o = r * (cos(a) * rightv + sin(a) * upv);
    text(ax, x + o(1), y + o(2), z + o(3), str, 'Color', th.lblHalo, 'FontName', cfg.font.name, ...
        'FontSize', style.size, 'FontWeight', style.weight, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Clipping', 'off', 'Tag', ['halo:' group]);
end
ray = [x y z] - campos_;   ray = ray / norm(ray);
tp = [x y z] - 0.004 * dd * ray;      % nudge along ITS OWN view ray: wins the depth test, no screen shift
h = text(ax, tp(1), tp(2), tp(3), str, 'Color', color, 'FontName', cfg.font.name, 'FontSize', style.size, ...
    'FontWeight', style.weight, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Clipping', 'off', ...
    'Tag', ['top:' group], 'UserData', role);
end
