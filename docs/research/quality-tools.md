# Quality tool contracts

Research findings for **"What does each candidate quality tool actually need to run?"**
([atsyplenkov/krv#2](https://github.com/atsyplenkov/krv/issues/2)).

Shortlist source: [mokevnin/dev-quality-gates](https://github.com/mokevnin/dev-quality-gates), `Recommendations` only
(`tools.json`). Nothing here is taken from *Under review* or `not-adopted.md`.

This file records **facts**, not recommendations. Every claim names the source that owns it.

Constraint the facts are measured against: the aggregate command `tool/check.py` must run on
**Windows**, **Termux/Android** and **Linux**.

---

## Summary

| Tool | Latest (checked) | Windows | Termux | Network | Gate exit | Baseline | Autofix |
|---|---|---|---|---|---|---|---|
| jactionlint | v2.3.0 | yes (PyPI) | untested | no¹ | non-zero | — | `--fix`, safe |
| Ruff | 0.17.2 | yes | **yes (apt 0.17.2)** | no | non-zero | `per-file-ignores` | `--fix` safe, `--unsafe-fixes` not |
| ty | 0.0.91 | yes (PyPI) | untested | no | non-zero | — | none |
| Betterleaks | **v1.9.0 stable** / v2.0.0-rc.4 | yes (zip) | **no** | no² | non-zero | allow comments | — |
| OSV-Scanner | v2.7.0 | yes | untested | **yes**³ | non-zero | — | none |
| typos | v1.51.1 | yes | **no** (cargo only) | no | **0 / 2**⁴ | config ignores | `-w` |
| rumdl | v0.3.0 (beta) | yes | untested | no | **0 / 1 / 2**⁵ | markdownlint config | `check --fix` |
| lychee | v0.24.2 stable | yes | **yes (apt 0.24.2)** | **yes** | non-zero | cache + excludes | none |
| check-jsonschema | 0.38.2 | yes | untested | no⁶ | non-zero | — | none |
| diff-cover | v10.6.0 | yes | untested | no | `--fail-under` | n/a | none |

1. `--online` does need network — it pins action tags to commit SHAs.
2. Local scan is offline. Optional live credential validation does need network.
3. Queries the OSV API by default. `--offline` with `--download-offline-databases` removes the need after one download.
4. `--format json`: exit 0 on clean, **exit 2 on typos**, anything else is an error. Non-standard — gate on non-zero, do not assume 1.
5. `0` success, `1` violations, `2` tool error. **`rumdl fmt` exits 0 even when violations remain.**
6. Remote schemas are fetched and cached. Vendoring the schema locally makes it offline and deterministic.

---

## Per-tool findings

### jactionlint — lints `*.github/workflows/*.yml` and `dependabot.yml`

- **Version**: v2.3.0 (2026-10-21). Pushed 2026-10-25. 283 stars. Actively releasing.
- **Install**: Homebrew tap, **PyPI** (`uvx jactionlint`, `pipx install jactionlint`, `uv tool install jactionlint`), Docker `ghcr.io/jdx/jactionlint`.
  The PyPI route is what makes Windows and Termux reachable — Python is present on both.
  Source: <https://github.com/jdx/jactionlint#readme>
- ⚠️ **Name collision**: *"Packages named `actionlint`, as in Homebrew core, install the original project, not this fork."*
  Installing the wrong binary is the default outcome on Homebrew. Source: `jdx/jactionlint` README.
- **Network**: offline by default. `--online` additionally pins action tags to commit SHAs — this needs network and would rewrite the workflow files.
- **Autofix**: `--fix` repairs only what has a mechanical fix.
- **Overlap**: also audits `dependabot.yml`, so it covers part of what `check-jsonschema` covers. Different job (policy/security vs schema validity), not a duplicate.
- ⚠️ **Maturity**: created October 2026, one maintainer, zizmor parity self-reported. `tools.json` names zizmor as the established fallback.

### Ruff — lints and formats `tool/*.py`

- **Version**: 0.17.2 (2026-10-22). 50,269 stars. Pushed 2026-10-25.
- **Install**: `uv tool install ruff`, `pip install ruff`, `pipx install ruff`, Homebrew, Conda.
  Source: <https://docs.astral.sh/ruff/>
- ✅ **Termux confirmed**: `ruff 0.17.2` is in the Termux apt repository and matches the upstream latest release exactly. Verified locally via `apt-cache policy`.
- **Windows**: README carries an explicit Windows section. Rust binary, no runtime needed.
- **Exit**: `ruff check` exits non-zero when it reports findings.
- **Autofix**: `ruff check --fix` is safe. `--unsafe-fixes` **must not** run unattended — it can change behaviour.
- **Baseline**: no `--ignore-known`. Per-rule and per-file ignores live in config (`per-file-ignores`, `# noqa`). Blast radius here is two files (`tool/android_release.py`, `tool/check.py`), so the baseline question is likely moot for Ruff.
- **Not a type checker** — `ty` is a separate job.

### ty — Python type checking

- **Version**: 0.0.91 (2026-10-22). 19,958 stars. Releases every few days.
- ⚠️ **Beta, 0.0.x**: `tools.json` states plainly *"new releases can add type errors; pin the version."* A tool that changes its verdict between patch releases is a poor gate.
- **Install**: PyPI (`pip install ty`, `uv tool install ty`). Not in the Termux apt repo.
- **Alternatives named by the source**: mypy (~160M downloads/month) and pyright are the stable choices; Pyrefly is the other Rust option.
- **Relevance here**: `tool/` is two Python files and a test file. The cost of a beta type checker is likely higher than the cost of the type errors it would find.

### Betterleaks — committed secrets

- **Stable line is v1.9.0** (2026-09-29). v2 is **release candidate only** (v2.0.0-rc.4, 2026-10-20).
  `tools.json` says to pin; this confirms the two lines are both live and divergent.
- **Release binaries**: `darwin_arm64`, `darwin_x64`, `linux_arm64`, `linux_x64`,
  **`windows_arm64`, `windows_x64`** — plus `checksums.txt` and a Sigstore attestation.
  Windows is covered by a direct download.
- ❌ **No Android/Termux build**, and `go install github.com/betterleaks/betterleaks/v2@latest`
  is the only other route named in the README — but **`go` is not in the Termux apt repo**.
  Verified locally. Betterleaks cannot run on Termux as things stand.
- **Install** otherwise: `brew install betterleaks` (plus a tap/cask, and `betterleaks@1` to keep v1),
  `sudo dnf install betterleaks`. Source: `betterleaks/betterleaks` README.
- **Network**: local file and history scanning is offline. Optional *live validation* of found credentials needs network.

### OSV-Scanner — known vulnerabilities

- **Version**: v2.7.0 (2026-10-12). 11,262 stars. Apache-2.0, from Google.
- ✅ **Scans this repo's lockfile.** The supported-artifacts table in source
  (`docs/supported_languages_and_lockfiles.md`) lists **Dart: `package_config.json`, `pubspec.lock`**.
  This repo commits `pubspec.lock`, so the scan has something to bite on. This was the single fact most likely to make the tool useless here.
- **Network**: queries the OSV API by default and sends package names, versions and file hashes.
  `--offline --download-offline-databases ./path` scans against a local database with no network
  after the initial download. Source: `google/osv-scanner` README.
- **Command**: `osv-scanner scan source -r <dir>` for a recursive source scan.
- **Install**: release binaries, Docker, `go install`.
- **Note**: `tools.json` warns it is not an image scanner, and that `trivy-action` must never be
  referenced by tag after the March 2026 compromise. Irrelevant here — no container images.

### typos — spelling in source and docs

- **Version**: v1.51.1 (2026-10-06). 4,196 stars.
- **Install**: `cargo install typos-cli --locked`, `brew install typos-cli`.
  ❌ **Not in the Termux apt repo.** `rust` (1.99.1) *is* present, so `cargo install` works but is slow.
- ⚠️ **Non-standard exit code**: `--format json` gives *"exit code 0 on no errors, **code 2 on typos**, anything else is an error."*
  Gate on **non-zero**, not on `== 1`.
- **Autofix**: `-w` writes corrections.
- **Config needs for this repo**: `locale` must be pinned (the docs are bilingual Russian/English),
  and `assets/fonts/**` needs excluding. `typos` only knows Latin-script misspellings, so Cyrillic
  prose is not checked — but transliterated Russian in code and commit text may be flagged.

### rumdl — Markdown lint and format

- **Version**: v0.3.0 (2026-10-17). 1,606 stars. README states explicitly:
  *"rumdl is currently **Beta** while its compatibility policy and 1.0 exit criteria are formalized."*
- **Install**: `brew`, `cargo install rumdl`, `npm install -g rumdl`, `pip install rumdl`, mise registry.
  Widest install surface of the ten.
- ⚠️ **Exit codes are asymmetric** (source: README "Exit Codes"):
  - `0` success · `1` violations · `2` tool error
  - **`rumdl fmt` exits 0 even when unfixable violations remain** — it is editor-oriented.
  - `rumdl check --fix` exits 0 if all fixed, **1 if violations remain**.
  **Gate on `rumdl check`, never `rumdl fmt`.**
- **Migration**: reads markdownlint configuration, so a `.markdownlint.json` carries over.
  Custom JavaScript rules written for markdownlint do **not** carry over.
- **Blast radius**: 8 Markdown files, several long and bilingual. Expect a large existing finding
  count — this is the tool most likely to need the baseline mechanism.

### lychee — broken links

- **Stable v0.24.2** (2026-05-01) — five months old. `nightly` tags are current (2026-10-22).
  Pin the stable, not nightly.
- ✅ **Termux confirmed**: `lychee 0.24.2` is in the Termux apt repository and matches the stable
  release. Verified locally via `apt-cache policy`.
- ⚠️ **Needs network** to check anything. `tools.json`: *"network flakiness; give it a GitHub token and a cache."*
  This makes it a CI/cron tool, not a local `check` tool — the local tier would be unreliable and slow.
- **This repo needs excludes**: `mailto:` links in `README.md`/`CONTRIBUTING.md` (a real address),
  and GitHub URLs that rate-limit without a token.

### check-jsonschema — validates config files

- **Version**: 0.38.2 (2026-09-23). 347 stars. ⚠️ `tools.json`: *"mostly a one-maintainer project."*
- **Install**: `pipx install check-jsonschema`, `brew install check-jsonschema`.
- **Schemas**: *"The schema may be specified as a local or remote (HTTP or HTTPS) file. Remote files are
  automatically downloaded and cached if possible."* Source: `python-jsonschema/check-jsonschema` README.
  → **Vendoring the schema in-repo removes the network dependency and makes the check deterministic.**
- **Ready-made hooks** exist for GitHub workflows and Dependabot, matching the files `jactionlint` audits.
- The README is a 59-line stub; real docs live at <https://check-jsonschema.readthedocs.io/>.

### diff-cover — coverage gate on changed lines

- **Version**: v10.6.0 (2026-09-22). 849 stars. Apache-2.0. Pure Python.
- ✅ **The gate flag is `--fail-under`.** `diff-cover coverage.xml --fail-under=80`.
  This is the exact fact `tools.json` recorded as *"the exact flag and exit code were not checked here."*
  Confirmed from `Bachmann1234/diff_cover` README.
- **Input formats**: Cobertura, Clover, JaCoCo, **lcov**. `flutter test --coverage` writes
  `coverage/lcov.info` — lcov is a supported input, so no format conversion is needed.
- **Install**: `pip install diff-cover`. No runtime beyond Python.
- **Network**: none.
- **Branch base**: it diffs against a git ref. In CI that means an explicit
  `--compare-branch=origin/main` and a checkout with enough history (`fetch-depth: 0` or a merge base).
  Without it the comparison is against the wrong base.

---

## Cross-cutting facts

**The Termux tier is the weak one.** Three of the ten are confirmed present in the Termux apt repo
(`ruff` 0.17.2, `lychee` 0.24.2, `shellcheck` 0.11.0-3). Two are confirmed **absent** (`typos`, and `go`
— which rules out Betterleaks' only non-brew install route). The rest are untested on Android.
Separately, Flutter itself is not installable on Termux, so `tool/check.py` can never fully run there:
the Dart checks would have to be skipped. This is already on the map as fog.

**Windows is the well-served one.** All ten publish a Windows path: PyPI wheels, `windows_x64.zip`
release assets, or cargo. No blocker there.

**Three tools must be pinned hard because they move fast or are pre-1.0:**
`ty` (0.0.x beta), `rumdl` (0.3.0 beta), `Betterleaks` (v2 is RC, v1.9.0 is stable).
`lychee` should pin to the stable line rather than nightly.

**Two tools cannot gate on exit code 1.** `typos` exits **2** on findings; `rumdl fmt` exits **0** on
findings. Anything aggregating them must treat *any non-zero* as failure and must call `rumdl check`,
not `rumdl fmt`.

**Two tools cannot run in a fast local tier.** `lychee` needs network; `OSV-Scanner` queries the OSV
API unless run in `--offline` mode with a pre-downloaded database.

---

## Not resolved here

Facts this research did not settle, and which a later ticket may need:

- Exact exit codes for `Betterleaks`, `OSV-Scanner`, `check-jsonschema`, `diff-cover` and `jactionlint`
  under *every* finding condition. READMEs document the happy path; `tool/check.py` should assert the
  failure path before trusting it. The adopt pattern in `dev-quality-gates` calls for proving each check
  can fail.
- Whether `jactionlint`, `ty`, `rumdl`, `check-jsonschema` and `diff-cover` have installable Termux
  paths. Python packages may install from source and fail.
- `typos`' actual finding count on this repository's bilingual docs, and whether `locale` plus
  `per-file` excludes are enough to make it quiet.
