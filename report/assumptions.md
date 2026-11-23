# Assumptions (all tagged in `config/parameters_sasg26.tsv`)
* Hot standoff R_hot_sub = 500 m around the 380 kV yard [ASSUMED]; sensitivity 250 / 1000 m.
* Cell size 250 m [ASSUMED]; sensitivity 100 / 500 m. Risk weights, saturation values, percentile: DAS-map design values retained [ASSUMED].
* Interrogator at the centroid of the 380 kV substation polygon (no separate control-room location in OSM) [ASSUMED]; lead-in straight, no slack.
* Lambda per zone: PLACEHOLDER / TBD. C_fiber, C_shelter (Stage G): not run.
* Vertical exaggeration 2, margins 0.05 / 0.012 deg, camera dist factor 0.88 (display only).
* Intruder / vehicle positions, ellipse sizes, camera spacing / range / FOV on the intruder map: ILLUSTRATIVE.
* Cameras: no plant cameras located from a source; none drawn on the twin. Fence climbing: no engine model (future work).
