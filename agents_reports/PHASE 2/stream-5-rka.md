# Stream 5 — RKA Subsystem

**Agent:** 10
**Group:** F — RKA Subsystem
**Files:** `rka/jsonarray.sh`, `rka/lspmcfg.sh`

## Actions Taken

1. **Created `src/rka/jsonarray.sh`** — copied verbatim from `main:Module/Yuri/rka/jsonarray.sh`. No changes needed (no hardcoded paths).

2. **Created `src/rka/lspmcfg.sh`** — copied from `main:Module/Yuri/rka/lspmcfg.sh` with one critical fix:
   - **Old (hardcoded):** `LSP_SQLITE="/data/adb/modules/Yurikey/Yuri/rka/${_lsp_abi}/sqlite3"`
   - **New (uses `$MODDIR`):** `LSP_SQLITE="${MODDIR}/rka/${_lsp_abi}/sqlite3"`
   - The path also reflects the new layout (`rka/` directly under module root, not under `Yuri/rka/`)

3. **No sqlite3 binaries bundled** — only the two shell scripts exist in `src/rka/`. Binaries are downloaded at install time by `customize.sh`.

## Checklist

- [x] `jsonarray.sh` copied to `src/rka/jsonarray.sh`
- [x] `lspmcfg.sh` copied to `src/rka/lspmcfg.sh` with path updated to use `$MODDIR`
- [x] No sqlite3 binaries in `src/rka/` (downloaded at install time)
- [x] No hardcoded `/data/adb/modules/Yurikey` references in `src/rka/`
