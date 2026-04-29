# Group B — Hiding & Config Features

**Stream:** Phase 2, Group B  
**Agent:** 6  
**Dependencies:** Stream 1 (lib/)  
**Files created:** 5

---

## Files Created

### `src/features/hma.sh`
- Sources `common.sh`, `paths.sh`, `urls.sh`
- Checks HMA-OSS installed via `pm list packages | grep -q org.frknkrc44.hma_oss`
- Legacy HMA (`com.tsng.hidemyapplist`) → deprecation warning, no config write
- Missing HMA-OSS → logs warning and exits 0 (graceful skip)
- Downloads config from `$HMA_CONFIG_URL` via shared `download()`
- **Security fix:** `chmod 600` (not 777)
- **Security fix:** Dynamic UID via `stat -c "%u" "$HMA_DIR"` → `chown $UID:$UID` (not hardcoded `u0_a0`)

### `src/features/znctl.sh`
- Sources `common.sh`, `paths.sh`
- Checks `/data/adb/modules/zygisksu/module.prop` exists
- **Bug fix #1:** Uses `$REQUIRED` (set to `1.3.0`) not undefined `$VERSION`
- **Bug fix #2:** Uses `log()` not typo `log_messgae`
- **Bug fix #3:** `ensure_dir "$(dirname "$SCRIPT_FILE")"` not `mkdir -p "$SCRIPT_FILE"` (was creating dir named `zygiskd`)
- Version comparison via `awk` (POSIX-compatible, works with BusyBox ash — no `sort -V`)
- Graceful skip if version too low or not installed

### `src/features/gms.sh`
- Sources `common.sh`, `paths.sh`
- Checks `pm list packages | grep -q com.android.vending` before acting
- Force-stops Play Store + clears cache via `cmd package trim-caches`
- Uses `exit` not `return`

### `src/features/kill_all.sh`
- Sources `common.sh`, `paths.sh`, `package_list.sh`
- Combines `$DETECTOR_APPS` + `$GMS_APPS` from `package_list.sh`
- **Bug fix:** Checks `pm list packages | grep -q "$pkg"` before acting on each package
- Missing packages skipped with `continue` (does not abort chain)
- Uses `exit` not `return`

### `src/features/rka.sh`
- Sources `common.sh`, `paths.sh`, `urls.sh`, `../rka/jsonarray.sh`
- **Critical change:** Uses `$RKA_TOKEN`, `$RKA_HOST`, `$RKA_TCP` from `urls.sh` (not hardcoded)
- Checks PassIt installed via `pm path io.github.mhmrdd.libxposed.ps.passit`
- Preserves existing RKA entry if found via `$IDFILE` UUID lookup
- Creates new entry if none exists, writes UUID to `$IDFILE`
- Deactivates all other RKA entries (only "Yuri RKA" active)
- Graceful skip if PassIt not installed

---

## Verification Results

| Check | Status |
|---|---|
| No hardcoded `/data/adb/modules/Yurikey` | ✅ |
| No `return` in feature scripts | ✅ |
| No `su -c` | ✅ |
| All scripts use `exit` | ✅ |
| Feature scripts use `"$MODDIR/../lib/"` sourcing | ✅ |
| `znctl.sh` uses `awk` (not `sort -V`) | ✅ |
| `rka.sh` sources `urls.sh` for `$RKA_TOKEN` | ✅ |
| `hma.sh` uses `chmod 600` | ✅ |
| `kill_all.sh` checks `grep -q` + `continue` | ✅ |
| `gms.sh` checks package existence | ✅ |
