function h = draw_fibre_sudair(ax, scene, lw)
% DRAW_FIBRE_SUDAIR  ADAPTED COPY (also: light pulses are short bright segments on the fibre instead of the Makkah-scale wide patches) of DAS-map draw_fibre.m (third_party/dasmap, a25fd0c): only the dashed 10 km "simulated section"
% corridor block is removed (it marks the Makkah trace stretch and would span half the plant). Everything else is unchanged.
% DRAW_FIBRE  3D glowing fibre following the terrain, coloured by vibration energy,
% with light pulses travelling outward from each interrogator (one frame of the animation).
cfg = scene.cfg;  c = cfg.col;  F = scene.fibre;   h = struct();   anim = isfield(scene, 'anim') && scene.anim;
x = [F.x; F.x(1)];  y = [F.y; F.y(1)];  z = [F.z; F.z(1)];  e = [F.energy; F.energy(1)];

plot3(ax, x, y, z, '-', 'Color', [c.cyan 0.14], 'LineWidth', 7 * lw);
plot3(ax, x, y, z, '-', 'Color', [c.cyan 0.30], 'LineWidth', 3.4 * lw);
colormap(ax, c.fibreCmap);   clim(ax, [0 1]);
h.core = patch(ax, 'XData', x, 'YData', y, 'ZData', z + 0.004, 'CData', e, 'FaceColor', 'none', ...
    'EdgeColor', 'interp', 'LineWidth', 1.9 * lw);

hot = e > scene.thresholdNorm;                        % widen the glow above the simulator's detection threshold
if anim
    % interactive version: one glow per event so each can be switched on at its own time (alpha 0 until then)
    Ev0 = scene.events;   sk = F.s_km(:);   Lk = F.L_km;   n0 = numel(sk);
    dI0 = abs(sk - Ev0.s_int);   dI0 = min(dI0, Lk - dI0);   dV0 = abs(sk - Ev0.s_veh);   dV0 = min(dV0, Lk - dV0);
    masks = {hot(1:n0) & dI0 < 3, hot(1:n0) & dV0 < 3};
    h.hot = struct('glow', {}, 'core', {});
    for q = 1:2
        xh = x(1:n0);  yh = y(1:n0);  zh = z(1:n0);   xh(~masks{q}) = NaN;
        h.hot(q).glow = plot3(ax, xh, yh, zh, '-', 'Color', [c.red 0], 'LineWidth', 13 * lw);
        h.hot(q).core = plot3(ax, xh, yh, zh + 0.006, '-', 'Color', [c.red 0], 'LineWidth', 3.6 * lw);
    end
elseif any(hot)
    xh = x;  yh = y;  zh = z;  xh(~hot) = NaN;
    plot3(ax, xh, yh, zh, '-', 'Color', [c.red 0.32], 'LineWidth', 13 * lw);
    plot3(ax, xh, yh, zh + 0.006, '-', 'Color', [c.red 0.95], 'LineWidth', 3.6 * lw);
end

if anim, return; end                                      % interactive version animates the pulses itself
L = F.L_km;  s = F.s_km(:);                              % light pulses: each IU launches into ONE channel (n_ch = 1),
for k = 1:F.nSeg                                          % one pulse train per channel, from the near end of its segment outward
    s0 = s(F.segNearIdx(k));
    for d = cfg.pulsePhase * cfg.pulseSpacingKm : cfg.pulseSpacingKm : F.segLenKm(k) - cfg.pulseLenKm
        drawPulse(ax, F, mod(s0 + F.segDir(k) * d, L), F.segDir(k), cfg, lw);
    end
end
end

function drawPulse(ax, F, sHead, dirn, cfg, lw)
% Short bright segment ON the fibre (display only): soft cyan glow + white core, no wider than the fibre glow.
c = cfg.col;  L = F.L_km;  s = F.s_km(:);
idx = ringIdx(s, L, sHead, mod(sHead - dirn * cfg.pulseLenKm, L));
if numel(idx) < 2, return; end
plot3(ax, F.x(idx), F.y(idx), F.z(idx) + 0.003, '-', 'Color', [c.cyan 0.45], 'LineWidth', 3.4 * lw);
plot3(ax, F.x(idx), F.y(idx), F.z(idx) + 0.005, '-', 'Color', [1 1 1 0.85], 'LineWidth', 2.4 * lw);
end

function idx = ringIdx(s, L, a, b)
lo = min(a, b);  hi = max(a, b);
if hi - lo <= L / 2, idx = find(s >= lo & s <= hi);
else, idx = [find(s >= hi); find(s <= lo)];
end
idx = idx(:);
end
