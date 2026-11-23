function north_arrow(ax, c, h, fillCol, edgeCol, cfg)
% NORTH_ARROW  North arrow in figure-normalised units (north is up on screen: both views look due north, az = 180).
% c = [x y] of the arrow's foot, h = height (normalised). Sizes scale with cfg.uiScale.
ks = cfg.uiScale;   fn = cfg.font;
w = 0.085 * ks / cfg.figSizeIn(1);   yt = c(2) + h;   yh = yt - 0.45 * h;
plot(ax, [c(1) c(1)], [c(2) yh], '-', 'Color', edgeCol, 'LineWidth', 2.6 * ks, 'Tag', 'north');
plot(ax, [c(1) c(1)], [c(2) yh], '-', 'Color', fillCol, 'LineWidth', 1.1 * ks, 'Tag', 'north');
patch(ax, [c(1) c(1) - w c(1) + w], [yt yh yh], fillCol, 'EdgeColor', edgeCol, 'LineWidth', 0.6 * ks, 'Tag', 'north');
dx = 0.0012 / ks;   dy = 0.0016 / ks;
for o = [-1 -1; -1 1; 1 -1; 1 1]'
    text(ax, c(1) + o(1) * dx * ks, yt + 0.024 * ks + o(2) * dy * ks, 'N', 'Color', edgeCol, 'FontName', fn.name, 'FontSize', 8 * ks, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Tag', 'north');
end
text(ax, c(1), yt + 0.024 * ks, 'N', 'Color', fillCol, 'FontName', fn.name, 'FontSize', 8 * ks, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'Tag', 'north');
end
