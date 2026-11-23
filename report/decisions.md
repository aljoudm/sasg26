# Decisions
1. **No wadi term (22 Nov 2026 answer from project lead).** DAS-map `intrinsic_risk_grid.m` has slope + road distance only; used unchanged. No wadi term was invented.
2. **Lambda per zone = TBD / PLACEHOLDER.** Makkah values are not reused; columns kept in `cells.csv` as the string `TBD`.
3. **Hot is forced** within R_hot_sub = 500 m [ASSUMED] of the 380 kV substation (OSM way 1317477365); k-means (k = 2) splits the remaining cells into Cold/Neutral. Sensitivity R_hot_sub 250/500/1000 m x cell 100/250/500 m in `results_zones/sensitivity.csv`.
4. **Risk roads** = DAS-map classes (motorway..tertiary + links); all roads are kept for drawing.
5. **Optimization source** = f51b223 from `full das/third_party/optimization`.
6. **No drones, UAVs or patrols** anywhere; cameras are the only verification asset.
