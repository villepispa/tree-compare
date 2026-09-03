# Tree.Compare

Headless folder-tree identity compare for packaging automation. Engines:
**Native**, **Robocopy**, and **Hybrid**. First target: workstation-vendor
**driver packages** that share a version but differ by release ID.

**License:** [MIT](LICENSE) · **Spec:** [docs/product-brief.md](docs/product-brief.md)

**Module:** `Tree.Compare` · **Prefix:** `Tc` · **Floor:** PowerShell 7.2+

Canonical ignore/align switch is `-CompareProfile` (alias `-Profile`) so callers
do not assign to automatic `$PROFILE`. Result objects still expose `.Profile`.

## Profiles (`-CompareProfile` / `-Profile`)

| Value | Ignores | Child-root align |
|-------|---------|------------------|
| **Default** | None (add `-Ignore` if needed) | Off unless you pass `-AlignChildRoots` |
| **DriverPackage** | `Thumbs.db`, `desktop.ini`, `.DS_Store`, `__MACOSX` (leaf or path segment) | On by default: if a root is exactly one child folder and no files, compare from that child (zip-extract wrapper). Override with `-AlignChildRoots:$false` |

Use **DriverPackage** for extracted OEM/workstation driver kits whose **version**
matches but the **release-ID** folder names differ. Extra `-like` patterns go on
`-Ignore`. See [examples/README.md](examples/README.md) for a Speed-then-Accuracy
walkthrough.

## Quick start

```powershell
Import-Module .\src\Tree.Compare\Tree.Compare.psd1 -Force
Compare-TcTree -PathA .\pkg-r1 -PathB .\pkg-r2 -Profile DriverPackage
```

Entry script (exit `0` identical, `1` timestamp-suspect, `2` different, `3` error):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\pkg-r1 -PathB .\pkg-r2 -Profile DriverPackage
```

Accuracy (hash same-length files; skip timestamp):

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\pkg-r1 -PathB .\pkg-r2 -Mode Accuracy -Profile DriverPackage
```

Agent one-liner:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\pkg-r1 -PathB .\pkg-r2 -Profile DriverPackage -AgentSummary
# → TC-COMPARE-OK verdict=Identical mode=Speed …
```

## Modes

| Mode | Timestamp | SHA256 |
|------|-----------|--------|
| **Speed** (default) | Compared; mismatch → `TimestampSuspect`, no hash | Not run |
| **Accuracy** | Skipped | Run for every same-path same-length file pair |

`ContentEqual` is the packager auto-pick gate. It is `true` only when `Verdict`
is `Identical`. Speed `Identical` is a **metadata** claim (paths + lengths +
UTC mtimes). Accuracy `Identical` is a **hash** claim (paths + lengths +
SHA256). Timestamp is never part of **content** identity; Speed only uses it as
a cheap stand-in. If Speed reports `TimestampSuspect`, re-run Accuracy.

## Engines

| Engine | Speed | Accuracy |
|--------|-------|----------|
| **Native** (default) | Get-ChildItem dictionaries; exact UTC mtime | SHA256 of same-path same-length files |
| **Robocopy** | List-only `/L /FFT /DST` (FAT 2-second + DST). Extra/New → path, Changed → length, Tweaked/Newer/Older → timestamp | `Verdict=Error` — not a hash oracle |
| **Hybrid** | Same as Robocopy | Native SHA256 on same-length pairs |

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\pkg-r1 -PathB .\pkg-r2 -Engine Robocopy -Profile DriverPackage
```

| Speed outcome | Verdict | ContentEqual | TimestampOnly |
|---------------|---------|--------------|---------------|
| Paths + length + UTC mtime all match | Identical | True | False |
| Paths + length match, mtime differs | TimestampSuspect | False | True |
| Path or length differs | Different | False | False |

`TimestampOnly` is the *suspect* flag (time-only diffs), not “we inspected
mtimes.” On Accuracy it stays `False` because timestamp is skipped.

Dictionary `entries=` can be larger than `ComparedFileCount`: the walk includes
directory nodes; length/hash run on **files**. `HashedCount` is **two SHA256
calls per file pair** (left and right).

## Validate (agents / CI discovery)

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck

pwsh -NoProfile -File .\scripts\Invoke-TcValidate.ps1 -AgentSummary
# Success line: TC-VALIDATE-OK
# PSA-less host: add -SkipLint
```

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — Keep a Changelog + SemVer
- [docs/issues.md](docs/issues.md) — product issue register (`TC-*`)
- [docs/product-brief.md](docs/product-brief.md) — specification

## Related

- Worked Speed/Accuracy output: [examples/README.md](examples/README.md)
- Shared primitives: [Spine.Automation](https://github.com/villepispa/spine-automation) — not this domain
- Live Driver Store: [driver-store-manager](https://github.com/villepispa/driver-store-manager) — not vendor payload trees
- Hash reputation: [hash-mass-downloader](https://github.com/villepispa/hash-mass-downloader) — not tree identity
