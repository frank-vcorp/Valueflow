# Valueflow — GitHub Actions Workflows

This directory contains the CI/CD pipelines for the **Valueflow Middleware** project.

## Workflows

| File | Purpose | Trigger |
|------|---------|---------|
| `ci.yml` | Continuous validation (typecheck, lint, build, tests, security scan) | push / PR to `main` |
| `build-installer.yml` | Compile the Windows `.exe` installer via Wine + Inno Setup | push to `main` (installer/middleware/assets changes) · manual dispatch |
| `release.yml` | Build the installer **and** publish a GitHub Release | push of tag `v*.*.*` |

## Architecture diagram

```
                         ┌──────────────────────────┐
                         │  push / PR to main       │
                         │  (any path)              │
                         └──────────┬───────────────┘
                                    │
                                    ▼
                       ┌────────────────────────┐
                       │  ci.yml                │
                       │  ├─ validate-middleware│
                       │  ├─ validate-installer │
                       │  └─ security-scan      │
                       └────────────────────────┘

       ┌────────────────────────────────────┐         ┌────────────────────────┐
       │ push to main with paths filter     │         │ git tag v1.0.0         │
       │ (installer/**, middleware/**,      │         │ git push origin v1.0.0 │
       │  assets/**)                        │         └───────────┬────────────┘
       └─────────────────┬──────────────────┘                     │
                         │                                        │
                         ▼                                        │
              ┌──────────────────────┐                            │
              │  build-installer.yml │◄───────────────────────────┘
              │  - Wine 32-bit       │       (reusable workflow call
              │  - Inno Setup 6.4.2  │        with release:true)
              │  - Xvfb              │
              └──────────┬───────────┘
                         │
              ┌──────────┴───────────┐
              │                      │
              ▼                      ▼
   ┌────────────────────┐   ┌──────────────────────┐
   │ Artifact (30 days) │   │ GitHub Release       │
   │ Valueflow-Setup-…  │   │ (only when release=  │
   │ .exe               │   │  true or via tag)    │
   └────────────────────┘   └──────────────────────┘
```

## Triggers in detail

### `ci.yml`

- **push** to `main`
- **pull_request** targeting `main`

Jobs (all on `ubuntu-latest`):
- **validate-middleware** — runs `npm ci`, `tsc --noEmit`, ESLint, `npm run build`, `npm test`.
- **validate-installer** — syntax-checks `install.ps1` with PowerShell AST parser, `bash -n` on `build-installer.sh`, and verifies that every `Source:` path in `installer.iss` exists.
- **security-scan** — runs Trivy filesystem scan on `middleware/` (severity CRITICAL + HIGH). **Non-blocking** (`continue-on-error: true`).

### `build-installer.yml`

- **push** to `main` when any of these paths change:
  - `installer/**`
  - `middleware/**`
  - `assets/**`
- **workflow_dispatch** (manual run from the Actions tab), with a `release` boolean input.

The job:
1. Installs Wine 32/64-bit, Xvfb, and `cabextract`.
2. Downloads the Inno Setup portable installer and installs it silently in a 32-bit Wine prefix.
3. Runs `npm ci && npm run build` for the middleware.
4. Compiles `installer/installer.iss` with `ISCC.exe` via Wine.
5. Verifies the `.exe` exists and has a valid PE header (`MZ` magic).
6. Uploads the `.exe` as artifact `Valueflow-Setup-v1.0-windows` (retention 30 days).
7. **Optional:** when triggered manually with `release=true`, creates a GitHub Release and attaches the `.exe`.

### `release.yml`

- **push** of any tag matching `v*.*.*` (e.g. `v1.0.0`, `v1.2.3`).

This workflow is a thin wrapper that calls `build-installer.yml` as a reusable workflow with `release: true`, producing a GitHub Release automatically on each tag.

## How to use

### Run validation manually

You don't need to — `ci.yml` runs on every push and PR. To re-run a failed job, open the Actions tab, select the run, and click **Re-run jobs**.

### Build the installer manually

1. Go to **Actions** → **Build Installer (Windows .exe)** → **Run workflow**.
2. (Optional) Tick **Create a GitHub Release with the .exe attached**.
3. Wait ~5–10 minutes (Wine + Inno Setup cold start is slow).
4. Download the artifact from the run summary page.

### Cut a release

```bash
# Make sure you're on main and the working tree is clean
git checkout main
git pull --rebase

# Create a tag (semver)
git tag v1.0.0
git push origin v1.0.0
```

Within ~5–10 minutes, a new GitHub Release will appear with `Valueflow-Setup-v1.0.exe` attached and auto-generated notes.

> **Note:** the `.exe` is **never** committed to the repo — it ships only via artifact or GitHub Release.

## Outputs

| Workflow | Output |
|----------|--------|
| `ci.yml` | Console logs, Trivy report (`trivy-fs-report` artifact) |
| `build-installer.yml` | `Valueflow-Setup-v1.0-windows` artifact (30-day retention), optional GitHub Release |
| `release.yml` | GitHub Release with `Valueflow-Setup-v1.0.exe` attached |

## Maintenance tips

- **Inno Setup version** is pinned in `build-installer.yml` via the `INNO_SETUP_VERSION` env var. Update both this var and the `installer.iss` `AppVersion` when bumping.
- **Node.js** is pinned to `20` in `ci.yml` to match `engines` in `middleware/package.json` (`>=20 <21`).
- **Wine 32-bit** is mandatory — Inno Setup 6.x ships only as 32-bit.
- **Xvfb** is required because Inno Setup's GUI installer needs a display; the `wine --verysilent` flag suppresses the actual dialogs.
- **`npm ci`** (not `npm install`) is used everywhere to guarantee reproducible installs from `package-lock.json`.
- **Concurrency groups** prevent redundant CI runs and overlapping release builds.
- **Trivy** uses severity `CRITICAL,HIGH` and `ignore-unfixed: true` to keep noise low; the scan is non-blocking so a CVE doesn't break CI.

## Security

- No secrets are stored in this repo.
- All `uses:` references are pinned to immutable major tags (`@v4`, `@v2`, `@0.28.0`) — never `@main`.
- Workflow permissions follow the principle of least privilege:
  - `ci.yml`: `contents: read` (default).
  - `build-installer.yml` and `release.yml`: `contents: write` (only when a release may be created).

## Local validation

```bash
# Syntax
yamllint .github/workflows/*.yml
actionlint .github/workflows/*.yml

# Middleware smoke test
cd middleware
npm ci
npx tsc --noEmit
npm test
```

If you have [`act`](https://github.com/nektos/act) installed:

```bash
act -j validate-middleware
```
