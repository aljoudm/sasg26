# Stage AI: classification of the Sudair events (SIMULATED)

**AI: full-das interface, stub (Pc from literature); real ViT-1D classifier trained/tested on Brno only, not yet connected**

Interface: `third_party/fulldas_ai/src/ai/ai_interface.m` (read-only copy of full-das, see its `PROVENANCE.md`), `use_real_ai = false`.
Events: the four Stage F events of `results/das_sudair.mat` (simulated, commercial interrogator parameters). Seed: RandStream Threefry 1, one stream per run.
Pc_DAS 0.983 to 0.993 [SOURCE: wang2024 via Shao 2025]; full-das tags it ASSUMED because literature figures from random-window splits are probably optimistic.
Routing as full-das `respond_day`: threat class -> ALARM -> camera verification; vehicle on the access road -> logged; the calibration sine is excluded from the alarm logic.
The calibration sine is passed with true class `no_event` [ASSUMED]. Confidence values are the stub's PLACEHOLDER confidence.

## Pc_0.983
base: uniform stub, Pc 0.983 (Pc_DAS low end, wang2024 via Shao 2025)

| Event | True class | Predicted class | Confidence | Route |
| --- | --- | --- | --- | --- |
| Sine 100 Hz (calibration) | no_event | no_event | 0.85 | excluded (calibration, not in the alarm logic) |
| Walking = map intruder | walking | walking | 0.79 | ALARM -> camera verification |
| Digging | digging | digging | 0.97 | ALARM -> camera verification |
| Vehicle = map vehicle (access road) | vehicle | vehicle | 0.61 | logged (vehicle on the access road) |

## Pc_0.993
base: uniform stub, Pc 0.993 (Pc_DAS high end, wang2024 via Shao 2025)

| Event | True class | Predicted class | Confidence | Route |
| --- | --- | --- | --- | --- |
| Sine 100 Hz (calibration) | no_event | no_event | 0.85 | excluded (calibration, not in the alarm logic) |
| Walking = map intruder | walking | walking | 0.79 | ALARM -> camera verification |
| Digging | digging | digging | 0.97 | ALARM -> camera verification |
| Vehicle = map vehicle (access road) | vehicle | vehicle | 0.61 | logged (vehicle on the access road) |

## Brno_sensitivity
Brno, 4 test recordings, SENSITIVITY (classes missing from the matrix fall back to the uniform stub, Pc 0.983)

| Event | True class | Predicted class | Confidence | Route |
| --- | --- | --- | --- | --- |
| Sine 100 Hz (calibration) | no_event | no_event | 0.97 | excluded (calibration, not in the alarm logic) |
| Walking = map intruder | walking | digging | 0.79 | ALARM -> camera verification |
| Digging | digging | digging | 0.78 | ALARM -> camera verification |
| Vehicle = map vehicle (access road) | vehicle | other | 0.63 | no alarm (non-threat class) |

## Figure labels (from run Pc_0.983)
| Figure element | Label |
| --- | --- |
| Twin and intruder map, intruder | Intruder: detected → AI: human (walking) (0.79) → ALARM |
| Twin, vehicle | Vehicle on access road → AI: vehicle (0.61) → logged |
| Intruder map, step 3 | 3  AI: human (walking) |
| STATUS panel note | AI: full-das interface (stub, Pc 0.983) |
