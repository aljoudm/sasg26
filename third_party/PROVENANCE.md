# Provenance of third_party/ (READ-ONLY copies; never edited)
| Folder | Source repo | Commit | Files |
| --- | --- | --- | --- |
| `dasmap/` | aljoudm/DAS-map- | a25fd0c049b885904fc58288d21ea3840e9f0427 | all root `*.m` and `data/*.m` (flat) |
| `das_engine/` | aljoudm/DAS-Simulation | 3a8862b2c77bca9c638bed08fe799cb36cc7171e | `src/*.m`, taken byte-for-byte from `full-das/third_party/das_engine` |
| `optimization/` | aljoudm/optimization | f51b2236d3eed2399c742c4c9318d2ea869972b1 | `src/`, `inputs/`, from `full-das/third_party/optimization` |
| `OTDR/` | aljoudm/OTDR- | 8d7331cfb61faf803634a3b0d0fc5dc5c093cb8c | `model/das_model.slx`, `scripts/otdr_params.m`, `figures/model_sections/*` (git show of that commit, no edits) |
Reference only, nothing copied: aljoudm/full-das a83a877 (conventions; reid_grid.csv row read for E2).

## Adapted copies in src/viz (third_party stays untouched)
`draw_fibre_sudair.m`, `draw_events_sudair.m`, `draw_assets_sudair.m`, `draw_status_sudair.m` are edited copies of DAS-map a25fd0c `draw_fibre.m`, `draw_events.m`, `draw_assets.m`, `draw_status.m` (changes listed in each header and in `report/decisions.md`). `draw_terrain`, `draw_risk`, `draw_trace`, `halo_text`, `set_camera`, `get_theme`, `panel_axes`, `north_arrow` are used unchanged from `third_party/dasmap`.
