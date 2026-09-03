# Changelog

All notable changes to **Tree.Compare** are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning aligns with [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Issue register: [docs/issues.md](docs/issues.md).

`[Unreleased]` stages changes for the **next** SemVer cut; it does not mean
the product is unpublished. Latest release is the first numbered section below.

## [Unreleased]

### Added

- **TC-002**: Robocopy and Hybrid engines. Speed uses list-only `robocopy /L
  /E /FFT /DST /IS /IT /XJ` (Extra/New → path-only, Changed → length,
  Tweaked/Newer/Older → timestamp). Hybrid Accuracy hashes with Native SHA256.
  `-Engine Robocopy -Mode Accuracy` returns `Error` (not a hash oracle). Native
  Speed still uses exact UTC mtimes.

### Changed

- VirusTotal workflow: `actions/upload-artifact@v4` → `@v7` (Node 24). GitHub
  hosted runners deprecated Node 20 and warn when v4 runs on Node 24 runners.

## [0.1.0] - 2026-08-24

### Added

- **TC-001**: Native engine; Speed/Accuracy cascade (Paths → Length →
  Timestamp in Speed → SHA256 in Accuracy); `DriverPackage` profile;
  headless verdict object; validate trio; extra ideas **TC-002**–**TC-010**
  filed in `docs/issues.md`.
- README + brief: `-CompareProfile` / `-Profile` (`Default` vs
  `DriverPackage`); Speed/Accuracy result-flag table; dictionary vs file
  counts. Worked Dell Intel graphics Speed-then-Accuracy example in
  `examples/README.md`.
- markdownlint ignore + VS Code tasks (call-through; default
  `Invoke-TcValidate.ps1`). Dual-host CI skipped (PS 7.2).
- GitHub Release VirusTotal URL scan workflow.

### Changed

- Canonical parameter `-CompareProfile` (alias `-Profile`) so scripts do not
  assign to automatic `$PROFILE` (`PSAvoidAssignmentToAutomaticVariable`).
  Result objects still expose `.Profile`.
