function ax = panel_axes(fig, pos, th, ks)
% PANEL_AXES  Rounded-rectangle-free panel background (axes with a framed rectangle), tagged 'panel' so a theme change can rebuild it.
if nargin < 4, ks = 1; end
ax = axes(fig, 'Position', pos);   hold(ax, 'on');
ax.XLim = [0 1];   ax.YLim = [0 1];   axis(ax, 'off');   ax.Tag = 'panel';
rectangle(ax, 'Position', [0 0 1 1], 'FaceColor', th.panel, 'EdgeColor', th.panelEdge, 'LineWidth', 0.6 * ks);
end
