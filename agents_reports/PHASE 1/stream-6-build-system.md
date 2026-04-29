# Stream 6 — Build System

## Summary
Created the build system infrastructure for the YuriKey module: package.json for dependency management and build scripts, updated .gitignore, and updated both CI workflow files (test and release).

## Files Created/Updated

### `package.json` (created)
- `name`: `yurikey-module`, `private: true`, `type: "module"` (ESM)
- **`build:web`** — bundles `src/webroot/index.html` via Parcel into `Module/webroot/`
- **`build:module`** — assembles the full module: copies `META-INF/`, `module.prop`, `lib/`, `features/`, `pipelines/`, `rka/`, top-level `*.sh`, `lang/`, `json/`, `common/` into `Module/`
- **`build`** — runs `build:web && build:module`
- **`dev`** — Parcel dev server for WebUI development
- `@material/web` (2.4.1) and `lit` (3.0.0) in `dependencies`
- `parcel` (^2.12.0) in `devDependencies`
- `kernelsu` (3.0.2) in `optionalDependencies` (not required — bridge detection handles absence)
- Targets: Chrome >= 100, distDir `./Module/webroot`

### `.gitignore` (updated)
Added: `key`, `attestation`, `Module/`, `node_modules/`, `.parcel-cache/`
Preserved existing: `Module/webroot/json/device-info.json`, `Module/webroot/lang/source/string.json`, `string.yml`
**Not added:** `config.json` (must stay tracked as download source for HMA config)

### `.github/workflows/build-test.yml` (rewritten)
- Trigger: `workflow_dispatch`
- Steps: checkout → Setup Node 22 → `shellcheck` on `src/*.sh` → `npm ci && npm run build` → verify module structure (module.prop, updater-script, index.html, common.sh, config_env.sh, module_paths.json) → check no hardcoded `/data/adb/modules/Yurikey` paths → check no `su -c` in features

### `.github/workflows/build-release.yml` (updated)
- Added `Setup Node` step (node-version: 22)
- Added `npm ci && npm run build` step before version extraction
- Rest of release flow preserved: version extraction from changelog.md, module.prop/update.json update, ZIP creation, commit+push, GitHub Release creation

## Checklist
- [x] `package.json` created with correct dependencies and build scripts
- [x] `.gitignore` updated with `key`, `attestation`, `Module/`, `node_modules/`, `.parcel-cache/`
- [x] `build-test.yml` updated with shellcheck + npm build + verify
- [x] `build-release.yml` updated with npm build step
