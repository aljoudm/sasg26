function das_figures()
% DAS_FIGURES  Stage F figures from results/das_sudair.mat (simulated, commercial interrogator parameters). Light theme, fig_style fonts,
% no in-figure titles, 300 dpi PNG + PDF in poster_figs/.
c = sasg_config();  addpath(fullfile(c.root, 'third_party', 'das_engine'));  S = run_das_sudair();  fig_style();
if ~exist(c.figDir, 'dir'), mkdir(c.figDir); end
set(groot, 'DefaultAxesXGrid', 'off', 'DefaultAxesYGrid', 'off');
credit = 'Simulated, commercial interrogator parameters (DAS-Simulation engine, 3a8862b). Channel length 16.28 km (lead-in + half of the 32.3 km fence).';
ha = {'left', 'right'};   % neighbouring event labels go to opposite sides so they do not overlap
%% 1 phase waterfall
f = figure('Color', 'w', 'Position', [60 60 940 540], 'Visible', 'off');  light_theme(f);  ax = axes(f);
imagesc(ax, S.WFz / 1e3, S.WFt, double(S.WF)');  set(ax, 'YDir', 'normal');  clim(ax, [0 40]);
colormap(ax, flipud(gray));  cb = colorbar(ax);  cb.Label.String = 'Vibration amplitude (nm rms, 18 ms blocks)';
xlabel(ax, 'Distance along the Sudair channel (km)');  ylabel(ax, 'Slow time (s)');  hold(ax, 'on');
for i = 1:numel(S.tab)
    plot(ax, S.tab(i).z0 / 1e3, max(S.WFt) * 1.0, 'v', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'MarkerSize', 7, 'Clipping', 'off');
    text(ax, S.tab(i).z0 / 1e3 + 0.12, max(S.WFt) * (0.97 - 0.07 * mod(sum([S.tab.z0] < S.tab(i).z0), 2)), lab(S.tab(i).type), 'Color', [0.8 0.1 0.1], 'FontWeight', 'bold', 'FontSize', 14, 'VerticalAlignment', 'top');
end
annotation(f, 'textbox', [0.01 0.005 0.98 0.04], 'String', credit, 'EdgeColor', 'none', 'FontSize', 9, 'Color', [0.35 0.4 0.45]);
save_fig_hq(f, c.figDir, 'das_waterfall');  close(f);
%% 2 recovered events: activity profile + true vs recovered time series
f = figure('Color', 'w', 'Position', [60 60 1100 620], 'Visible', 'off');  light_theme(f);
tl = tiledlayout(f, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');  tl.OuterPosition = [0 0.05 1 0.95];
ax = nexttile(tl, 1, [1 4]);  hold(ax, 'on');
plot(ax, S.z / 1e3, S.act, '-', 'Color', [0 0.5 0.68], 'LineWidth', 0.6);  yline(ax, S.thr, '--', 'Color', [0.8 0.1 0.1], 'LineWidth', 1);
text(ax, 0.1, S.thr, ' threshold (median + 8 MAD)', 'Color', [0.8 0.1 0.1], 'VerticalAlignment', 'bottom');
for i = 1:numel(S.tab)
    plot(ax, S.tab(i).z_est / 1e3, S.tab(i).peak_nm, 'o', 'MarkerFaceColor', [0.85 0.4 0.1], 'MarkerEdgeColor', 'none');
    text(ax, S.tab(i).z_est / 1e3, S.tab(i).peak_nm * 1.08, sprintf('%s: error %.1f m', lab(S.tab(i).type), S.tab(i).pos_err_m), 'HorizontalAlignment', ha{1 + mod(sum([S.tab.z0] < S.tab(i).z0), 2)}, 'FontSize', 12);
end
xlabel(ax, 'Distance (km)');  ylabel(ax, 'Activity (nm rms)');  xlim(ax, [0 S.z(end) / 1e3]);  ylim(ax, [0 max(S.act) * 1.25]);
for i = 1:4
    a = nexttile(tl, 4 + i);  hold(a, 'on');  m = S.t >= 0 & S.t <= 0.5;
    plot(a, S.t(m), S.TS{i}(1, m) * 1e9, '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.4);
    plot(a, S.t(m), S.TS{i}(2, m) * 1e9, '-', 'Color', [0.8 0.1 0.1], 'LineWidth', 0.7);
    xlabel(a, 'Time (s)');  if i == 1, ylabel(a, 'Elongation (nm)'); legend(a, {'true', 'recovered'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'FontSize', 11); end
    title(a, {lab(S.tab(i).type), sprintf('r = %.3f, amp. ratio %.2f', S.tab(i).corr, S.tab(i).amp_ratio)}, 'FontSize', 10, 'FontWeight', 'normal');
end
annotation(f, 'textbox', [0.01 0.005 0.98 0.04], 'String', credit, 'EdgeColor', 'none', 'FontSize', 9, 'Color', [0.35 0.4 0.45]);
save_fig_hq(f, c.figDir, 'das_recovered_events');  close(f);
%% 3 detected events only (poster panel: large text; correlations are in the poster table)
f = figure('Color', 'w', 'Position', [60 60 900 420], 'Visible', 'off');  light_theme(f);
ax = axes(f, 'Position', [0.09 0.20 0.89 0.74]);  hold(ax, 'on');  ax.FontSize = 15;
plot(ax, S.z / 1e3, S.act, '-', 'Color', [0 0.5 0.68], 'LineWidth', 0.8);  yline(ax, S.thr, '--', 'Color', [0.8 0.1 0.1], 'LineWidth', 1.4);
text(ax, 0.1, S.thr, ' threshold', 'Color', [0.8 0.1 0.1], 'VerticalAlignment', 'bottom', 'FontSize', 15);
for i = 1:numel(S.tab)
    plot(ax, S.tab(i).z_est / 1e3, S.tab(i).peak_nm, 'o', 'MarkerSize', 8, 'MarkerFaceColor', [0.85 0.4 0.1], 'MarkerEdgeColor', 'none');
    text(ax, S.tab(i).z_est / 1e3, S.tab(i).peak_nm * 1.1, sprintf(' %s: %.1f m ', lab(S.tab(i).type), S.tab(i).pos_err_m), 'HorizontalAlignment', ha{1 + mod(sum([S.tab.z0] < S.tab(i).z0), 2)}, 'VerticalAlignment', 'bottom', 'FontSize', 17, 'FontWeight', 'bold');
end
xlabel(ax, 'Distance along the Sudair channel (km)', 'FontSize', 16);  ylabel(ax, 'Activity (nm rms)', 'FontSize', 16);
xlim(ax, [0 S.z(end) / 1e3]);  ylim(ax, [0 max(S.act) * 1.45]);
annotation(f, 'textbox', [0.01 0.0 0.98 0.06], 'String', credit, 'EdgeColor', 'none', 'FontSize', 10, 'Color', [0.35 0.4 0.45]);
save_fig_hq(f, c.figDir, 'das_detected_events');  close(f);
fprintf('Saved poster_figs/das_waterfall, das_recovered_events and das_detected_events\n');
end
function light_theme(f)
% Figures stay light on computers whose MATLAB desktop uses the dark theme (R2025a+).
if exist('theme', 'file'), theme(f, 'light'); end
end
function s = lab(t)
switch string(t), case "sine", s = 'calibration sine'; case "walk", s = 'walking'; case "dig", s = 'digging'; otherwise, s = 'vehicle'; end
end
