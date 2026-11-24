# Provenance: full-das AI interface (read-only copy)

Copied unchanged from aljoudm/full-das, commit `a83a877594e7c3c8b1c493a6c286364667c2be86`, on 24 Nov 2026. The folder layout of full-das is kept
(`src/ai`, `config`, `results/classifier/T1s`), so `ai_interface.m` finds its config at the same relative path without any code edit.

| File here | Source in full-das |
| --- | --- |
| `src/ai/ai_interface.m` | `src/ai/ai_interface.m` |
| `config/ai_config.json` | `config/ai_config.json` (use_real_ai = false, mode uniform, Pc 0.983) |
| `config/class_map.yaml` | `config/class_map.yaml` |
| `results/classifier/T1s/confusion_matrix.csv` | `results/classifier/T1s/confusion_matrix.csv` (Brno, 4 test recordings; SENSITIVITY only) |

Do not edit these files. `src/ai/run_ai_sudair.m` runs the Pc = 0.993 end from a temporary copy (tempdir) in which only `Pc` is changed;
the Brno sensitivity uses the interface's own run-time switch `AI_CLASSIFIER_MODE=confusion_counts`.
Pc_DAS 0.983 to 0.993: `config/parameters_reviewed.tsv` of full-das, row Pc_DAS [SOURCE: wang2024 via Shao 2025; tagged ASSUMED there because
literature figures from random-window splits are probably optimistic].
