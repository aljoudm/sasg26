# sasg26: DAS perimeter security for Sudair PV (1.5 GW), SASG 26 poster
Port of the capstone pipeline (Makkah boundary) to Sudair PV, Sudair Industrial City, Saudi Arabia. Site inputs recomputed; code, methods and
FEBUS A1-NEO engine parameters reused. Sudair has cameras only: no patrols, no drones.

## Status
| Stage | State | Main output |
| --- | --- | --- |
| A boundary | done | `data/boundary_perimeter.csv` (OSM way 1317477364, 29.08 km2, L_boundary 32.304 km) |
| B terrain | done | `data/dem/` |
| C zones | done | `results_zones/` (Hot 4.52 / Neutral 6.95 / Cold 20.83 km) |
| D placement | done | `results/placement.*` (1 interrogator, 2 spare channels) |
| E 3D twin, E2 intruder map | done | `poster_figs/twin3d.*`, `poster_figs/intruder_map.*` |
| F DAS engine | done | `poster_figs/das_*`, `results/das_recovered_events.csv` (simulated, FEBUS A1-NEO parameters) |
| G MILP and costs | not done | |

Numbers with sources and regenerating scripts: `report/key_numbers.md`. Parameters with tags: `config/parameters_sasg26.tsv`. Decisions: `report/decisions.md`. Run: `RUN.md`.

## References
* OpenStreetMap contributors (ODbL): plant way 1317477364, substation way 1317477365, roads. Overpass API.
* Copernicus DEM GLO-30 (ESA, AWS Open Data). Imagery: Esri, Vantor, Earthstar Geographics, and the GIS User Community (World Imagery).
* NS Energy, Sudair PV Solar Power Plant (published area 30.2 km2; key `nsenergy_sudair`).
* FEBUS Optics A1-NEO datasheet rev. 20260618 (R_DAS 20 km, 4 channels, 5-40 degC).
* Source repositories (read-only): aljoudm/DAS-map- a25fd0c; aljoudm/DAS-Simulation 3a8862b; aljoudm/OTDR- 8d7331c; aljoudm/optimization f51b223; aljoudm/full-das (re-ID grid row, SIMULATED). See `third_party/PROVENANCE.md`.
