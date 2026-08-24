# Examples

Point `-PathA` and `-PathB` at two extracted driver package folders. Release-ID
folder names can differ; payload relative paths shouldn't. Use
`-CompareProfile DriverPackage` (alias `-Profile`).

## Speed then Accuracy (Dell Intel graphics kits)

Two workstation packages, same driver version (`32.0.101.8860`), different Dell
release IDs (`W8X2C` vs `T43TD`). Compared the inner payload folders
(`Drivers\8860` vs `Drivers\kit_922757_101.8860`), not the zip wrappers.

### Speed (default)

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\Drivers\8860 `
  -PathB .\Drivers\kit_922757_101.8860 `
  -CompareProfile DriverPackage
```

Observed (v0.1 Native):

| Status / field | Value | Meaning |
|----------------|-------|---------|
| Banner | `mode=Speed … profile=DriverPackage alignChildRoots=True` | DriverPackage default align |
| Dictionaries | `entries=342` each | Walk includes directories |
| Paths | `leftOnly=0 rightOnly=0` | Same relative path set |
| Length | `mismatch=0 sameLength=313` | 313 files, same sizes |
| Timestamp | `mismatch=0 skippedHash=313` | UTC mtimes matched; no hash |
| Hash | `skipped (Speed)` | Spec |
| `Verdict` / `ContentEqual` | Identical / True | Packager may auto-pick (metadata) |
| `TimestampOnly` | False | No time-only suspects |
| `HashedCount` / `HashSkippedCount` | 0 / 313 | Speed never hashes |
| `ComparedFileCount` | 313 | File pairs, not dir nodes |
| `ElapsedMs` | ~800 | Metadata only |

`ContentEqual=True` on Speed **doesn't** mean bytes were hashed. It means
Speed’s cascade passed, so a packager *may* auto-pick. Confirm with Accuracy
when you need a SHA256 proof.

### Accuracy

Same roots, add `-Mode Accuracy`:

```powershell
pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 `
  -PathA .\Drivers\8860 `
  -PathB .\Drivers\kit_922757_101.8860 `
  -Mode Accuracy `
  -CompareProfile DriverPackage
```

Observed (same trees):

| Status / field | Value | Meaning |
|----------------|-------|---------|
| Timestamp | `skipped (Accuracy)` | Spec |
| Hash | `hashedFiles=626 mismatch=0` | 313 pairs × 2 SHA256 |
| `HashedCount` / `HashSkippedCount` | 626 / 0 | Every candidate hashed |
| `Verdict` / `ContentEqual` | Identical / True | Hash-backed auto-pick |
| `ElapsedMs` | ~106000 | Expected vs Speed ~800 |

Together: Speed said pick either from metadata; Accuracy proved the bytes
match. A later packager can auto-pick either release ID for that version.

If Speed had returned `TimestampSuspect` (`TimestampOnly=True`), Accuracy
would still be the content check — ZIP extract often rewrites mtimes.
