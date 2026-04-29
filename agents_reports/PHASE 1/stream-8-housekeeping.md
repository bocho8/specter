# Stream 8 — Housekeeping Report

**Date:** 2026-04-29
**Branch:** rewrite-v3.1.0

## Checklist

| Item | Status | Notes |
|------|--------|-------|
| Delete `src/webroot/common/assets/` | N/A | `src/` directory doesn't exist yet — this path will never be created in the new structure (unreferenced) |
| Delete `src/webroot/common/boot_hash.sh` | N/A | `src/` directory doesn't exist yet — handled by creating only one canonical copy at `features/boot_hash.sh` |
| `.gitignore` entries (`key`, `attestation`, `Module/`, `node_modules/`, `.parcel-cache/`) | ✅ Done | All entries already present; `config.json` correctly excluded from `.gitignore` |
| `git rm --cached key` | ✅ Done | `key` removed from git tracking (staged for commit) |
| `git rm --cached attestation` | N/A | `attestation` was never tracked |
| `git rm --cached config.json` | ❌ NOT done | Intentionally skipped — `config.json` must stay tracked as download source for HMA config |

## Details

### `.gitignore` (pre-existing content)
```
key
attestation
Module/
node_modules/
.parcel-cache/
Module/webroot/json/device-info.json
Module/webroot/lang/source/string.json
string.yml
```

All Stream 8 required entries were already in place. No modifications needed.

### Git tracking
- `key` — successfully removed from tracking via `git rm --cached key`
- `attestation` — never committed, no action required
- `config.json` — intentionally left tracked (per spec)

### Files to delete
The two files listed for deletion (`src/webroot/common/assets/` and `src/webroot/common/boot_hash.sh`) are in the new `src/` layout which hasn't been created yet. When Stream 1+ create these paths, they should ensure:
- `assets/` is never created (it's unreferenced in the new structure)
- `boot_hash.sh` lives only at `features/boot_hash.sh`, not duplicated in `webroot/common/`
