# Agent 8 (Group D) — Stream 3: Orchestrator + Pipelines

## Summary

Created the pipeline-driven orchestrator and its two pipeline definition files.

## Files Created

| File | Purpose |
|------|---------|
| `src/orchestrator.sh` | Pipeline runner: reads pipeline file, iterates features, handles `?` optional suffix and `#` comments, aborts on failure |
| `src/pipelines/full_integrity` | Defines: `gms.sh → target.sh → security_patch.sh → boot_hash.sh → keybox.sh → pif.sh?` |
| `src/pipelines/root_hide` | Defines: `hma.sh → znctl.sh?` |

## Design Details

- **Root-level script** — uses `"$MODDIR/lib/common.sh"` (direct path, not `../lib/`)
- **Pipeline reading** — `while IFS= read -r line` with no subshell issues
- **`#` comments** — lines starting with `#` are skipped
- **`?` optional suffix** — if the feature file doesn't exist, logs a warning and continues
- **Empty lines** — skipped
- **Error handling** — any feature returning non-zero calls `die()` and aborts
- **POSIX-compatible** — works in `/system/bin/sh` on Android
