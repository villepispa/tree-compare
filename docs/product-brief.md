# Tree.Compare — product brief

**Module:** `Tree.Compare` (`Tc` prefix, issue IDs `TC-*`)

**Host floor:** PowerShell 7.2+
**License:** MIT
**Status:** Latest release **v0.2.0** (Native, Robocopy, Hybrid).

---

## Executive summary

Compare two folder trees for **content identity**. Primary use: two vendor
driver packages with the same version and different release IDs. A later
packager (product undefined) calls this tool: if `ContentEqual`, pick either;
otherwise ask. This module does **not** prompt.

## Placement

Independent OSS product. Not Spine.Automation (shared primitives only), not
Driver Store Manager (live `pnputil` store), not Hash.MassDownloader (hash
for reputation).

## Scope

### In scope (v0.2.0)

| Capability | Notes |
|------------|-------|
| File dictionaries | One walk per root; `Hashtable` keyed by normalized relative path |
| Speed mode | Paths → Length → Timestamp; no SHA256 |
| Accuracy mode | Paths → Length → SHA256; timestamp skipped |
| Verdicts | `Identical`, `TimestampSuspect`, `Different`, `Error` |
| DriverPackage profile | `-CompareProfile DriverPackage` (alias `-Profile`). Ignore `Thumbs.db` / `desktop.ini` / `.DS_Store` / `__MACOSX`; default `-AlignChildRoots` when a root is a single child folder with no files |
| Status | Mode banner; per-step START/DONE; `-Detailed` lists; `-AgentSummary` |
| Exit codes | 0 / 1 / 2 / 3 |
| Robocopy engine | Speed list-only `/L` `/E` `/FFT` `/DST` `/IS` `/IT` `/XJ`. Extra/New → path-only, Changed → length, Tweaked/Newer/Older → timestamp. Accuracy returns `Error` (not a hash oracle). |
| Hybrid engine | Robocopy Speed + Native SHA256 in Accuracy. |

### Out of scope (roadmap)

| Capability | Tracking |
|------------|----------|
| Dictionary export/import | TC-003 |
| Parallel SHA256 | TC-004 |
| Moved-file (same hash, new path) | TC-005 |
| INF / CAT / Authenticode compare | TC-006 (packager) |
| Product ShellGuard pack | TC-007 |
| Follow reparse points | TC-008 |
| Native FAT/DST time tolerance | TC-009 |
| Packager product (prompt which tree) | TC-010 |

## Semantics

**Identical** = same relative path set + same file lengths + (Speed: same
UTC timestamps **or** Accuracy: same SHA256). Timestamp is never part of
**content** identity.

**TimestampSuspect** = Speed found time-only diffs. Re-run Accuracy. Typical
for ZIP-extracted OEM driver drops.

**ContentEqual** = packager auto-pick gate (`true` only for `Identical`).
On Speed that is a metadata claim (no SHA256). On Accuracy it is a hash
claim. `HashedCount=0` distinguishes the two.

**TimestampOnly** = `true` only when paths and lengths match **and** at least
one UTC mtime differs (the TimestampSuspect path). It is not “timestamp was
compared.” Accuracy leaves it `false` because mtime is skipped.

Speed never hashes. Accuracy never uses timestamp.

### Compare profiles

Parameter: `-CompareProfile` (alias `-Profile`; do not name the variable
`$Profile` — that shadows automatic `$PROFILE`). Result property remains
`.Profile`.

| `-CompareProfile` | Ignore patterns | `-AlignChildRoots` default |
|-------------------|-----------------|----------------------------|
| `Default` | None | Off unless the switch is passed |
| `DriverPackage` | `Thumbs.db`, `desktop.ini`, `.DS_Store`, `__MACOSX` | On (single child folder, no files at the root) |

`-Ignore` appends extra `-like` patterns (leaf, full relative path, or
segment). Worked Speed-then-Accuracy numbers:
[examples/README.md](../examples/README.md).

## Engine

**Native** (default) walks each root into a Hashtable.

**Robocopy** is a Speed accelerator: list-only `robocopy /L /E /FFT /DST /IS
/IT /XJ`. Extra/New → path-only, Changed → length, Tweaked/Newer/Older →
timestamp. `-Engine Robocopy -Mode Accuracy` returns `Verdict=Error`. Use
**Hybrid** or **Native** for Accuracy.

**Hybrid** = Robocopy Speed + Native SHA256 in Accuracy. Not a hash oracle.

FAT timestamps have **2-second** granularity (`/FFT`) and a one-hour DST
compensation (`/DST`); both apply only to Robocopy/Hybrid Speed. Native Speed
still uses exact UTC equality (TC-009). A 1-second mtime gap in tests is a
sample *inside* the 2-second window, not a 1-second spec.

## Object model (result)

| Field | Meaning |
|-------|---------|
| `Verdict` | `Identical` \| `TimestampSuspect` \| `Different` \| `Error` |
| `ContentEqual` | Packager may auto-pick (`true` only if `Verdict` is `Identical`) |
| `TimestampOnly` | Speed time-only suspects (`true` → re-run Accuracy) |
| `LeftOnlyCount` / `RightOnlyCount` | Path-set diffs |
| `LengthMismatchCount` | Same path, different size |
| `TimestampMismatchCount` | Speed only |
| `HashMismatchCount` | Accuracy only |
| `HashedCount` / `HashSkippedCount` | SHA256 calls (two per file pair) vs skipped |
| `ComparedFileCount` | Same-path file pairs in the length stage (not directory nodes) |
| `LeftOnly` … `HashMismatch` | Path lists (always present; `-Detailed` also prints) |

## Safety

Read-only. Safety tier **1**. Does not follow reparse points. Does not copy,
delete, or prompt.
