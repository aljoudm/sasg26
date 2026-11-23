# RUN
MATLAB R2026a, run from this folder: `matlab -batch "main"` (first run needs internet: Overpass, Copernicus on AWS, Esri export).
Single stages: `addpath('config'); sasg_config();` then `fetch_boundary_sudair`, `prepare_terrain_sudair`, `run_zones`, `place_fibre_sudair`,
`run_das_sudair(true)`, `das_figures`, `render_twin_sudair(300)`, `render_intruder_map(300)`. Tests: `tests/test_stage{A,C,D,E,E2,F}.m`.
Order matters: D before F and E (placement and scenario). `render_intruder_map` reads `full das/results/reid/reid_grid.csv` (read-only, Desktop path in the script).
Stage B is not covered by a test; Stage G (MILP) is not implemented.
