# Issues — Tree.Compare

Product issue register. IDs are stable (`TC-NNN`). Newest first.

## Workflow

- **Status:** `Open` / `in-progress` / `done` / `backlog`
- Keep issue identifiers stable; never reuse an ID

## Done

| ID | Title | Status | Notes |
|----|-------|--------|-------|
| TC-002 | Robocopy + Hybrid engines | done | Released **v0.2.0**. Speed `/L` `/FFT` `/DST`; Hybrid Accuracy Native hash. Claimed `TC-VALIDATE-OK` Pester 18/18. Accepted [2026-09-03 09:01:00](../CHANGELOG.md) (user `accept`). Named acceptor Ville ≠ claimant. |
| TC-001 | Product brief + v0.1 Native scaffold | done | Validate trio; Speed/Accuracy; DriverPackage; first public tag v0.1.0 |

## Backlog (extra ideas and next steps)

| ID | Title | Status | Notes |
|----|-------|--------|-------|
| TC-010 | Packager consumer (undefined product) | backlog | Uses `ContentEqual`; owns “which tree?” prompt |
| TC-009 | Native FAT/DST timestamp tolerance | backlog | 2-second window in Speed; Robocopy `/FFT` in TC-002 |
| TC-008 | Optional follow reparse points | backlog | v0.1 skips junctions |
| TC-007 | Product ShellGuard pack | backlog | spine-automation `templates/ps-product-shellguard/` |
| TC-006 | INF-aware compare | backlog | Packager domain (`DriverVer` / CAT), not this module |
| TC-005 | Moved-file detection | backlog | Second index by SHA256 |
| TC-004 | Parallel SHA256 in Accuracy | backlog | `ForEach-Object -Parallel` |
| TC-003 | Dictionary export/import | backlog | Snapshot `{RelPath,Length,LastWriteTimeUtc,Sha256?}` |

## Notes

### TC-001 — v0.1 Native scaffold

**Acceptance:** `Invoke-TcValidate.ps1 -AgentSummary` → `TC-VALIDATE-OK`;
Pester covers Identical, TimestampSuspect vs Accuracy Identical, length
mismatch, path-only, DriverPackage ignore, AlignChildRoots, unimplemented
engine Error. No private backlog prefixes in this tree.

### TC-002 — Robocopy engine

Map Extra/New → path-only, Changed → length, Tweaked/Newer/Older →
timestamp. Hybrid = Robocopy Speed + Native Accuracy. Not a hash oracle.
List-only flags: `/L /E /FFT /DST /IS /IT /XJ`. Extra Dir children are
walked after parse so dest-only trees list files, not only the directory
node. Accepted 2026-09-03 09:01:00 (Ville, user `accept`) ≠ claimant.
Readback: `TC-VALIDATE-OK` Pester 18/18, PSA findings=4 errors=0.

### TC-010 — Packager

Separate product. Tree.Compare stays headless. If `ContentEqual`, pick
either; else operator chooses.
