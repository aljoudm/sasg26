function th = get_theme(cfg, name)
% GET_THEME  Colours for everything OUTSIDE the map imagery (page, panels, frames, text) and for
% labels drawn over the imagery. The scene itself (terrain, fibre, assets) is identical in both themes.
c = cfg.col;
switch lower(name)
    case 'dark'
        th.name = 'dark';
        th.bg = c.bg;            th.text = c.text;         th.muted = [0.58 0.68 0.74];
        th.panel = [0.075 0.115 0.155];   th.panelEdge = [0.20 0.38 0.46];
        th.frame = [0.96 0.98 1.00];  th.grid = [0.22 0.30 0.36];
        th.trace = c.cyan;       th.thr = [1.00 0.35 0.30];
        th.lblText = c.text;     th.lblHalo = [0.02 0.05 0.08];
        th.iuLbl = c.cyan;       th.intLbl = [1.00 0.58 0.52];   th.aniLbl = c.yellow;
        th.credit = [0.70 0.78 0.84];
    case 'light'
        th.name = 'light';
        th.bg = [1 1 1];         th.text = [0.07 0.10 0.14];   th.muted = [0.38 0.43 0.48];
        th.panel = [0.965 0.975 0.985];   th.panelEdge = [0.60 0.68 0.74];
        th.frame = [0.04 0.22 0.42];      th.grid = [0.82 0.86 0.89];
        th.trace = [0.00 0.50 0.68];      th.thr = [0.80 0.10 0.10];
        th.lblText = [0.07 0.10 0.14];    th.lblHalo = [1 1 1];
        th.iuLbl = [0.00 0.40 0.56];      th.intLbl = [0.78 0.10 0.10];   th.aniLbl = [0.60 0.40 0.00];
        th.credit = [0.35 0.40 0.45];
    otherwise
        error('Unknown theme "%s" (use dark or light).', name);
end
end
