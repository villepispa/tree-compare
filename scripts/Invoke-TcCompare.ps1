#Requires -Version 7.2
<#
.SYNOPSIS
  Compare two folder trees (Native, Robocopy, or Hybrid).

.DESCRIPTION
  **Safety tier: 1**

  Headless identity compare. Timestamp mismatches in Speed do not prove
  content difference (TimestampSuspect). Accuracy hashes same-length files.

.PARAMETER PathA
  Left tree root.

.PARAMETER PathB
  Right tree root.

.PARAMETER Mode
  Speed (default) or Accuracy.

.PARAMETER Engine
  Native (default dictionaries), Robocopy (Speed-only /L /FFT /DST), or
  Hybrid (Robocopy Speed + Native Accuracy hash).

.PARAMETER CompareProfile
  Default or DriverPackage. Alias: Profile.
  DriverPackage ignores Thumbs.db, desktop.ini, .DS_Store, __MACOSX and
  aligns a single child-folder wrapper by default.

.PARAMETER Ignore
  Extra ignore patterns.

.PARAMETER IgnoreEmptyDirectories
  Omit directory entries.

.PARAMETER AlignChildRoots
  Descend into a single child folder. Default on for DriverPackage.

.PARAMETER Detailed
  Print per-path misfindings.

.PARAMETER Quiet
  Suppress host status (implied by -AgentSummary).

.PARAMETER AgentSummary
  One success-stream line: TC-COMPARE-OK | TC-COMPARE-FAIL. Exit 0/1/2/3.

.EXAMPLE
  pwsh -NoProfile -File .\scripts\Invoke-TcCompare.ps1 -PathA .\a -PathB .\b -Profile DriverPackage
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PathA,

    [Parameter(Mandatory)]
    [string]$PathB,

    [ValidateSet('Speed', 'Accuracy')]
    [string]$Mode = 'Speed',

    [ValidateSet('Native', 'Robocopy', 'Hybrid')]
    [string]$Engine = 'Native',

    [ValidateSet('Default', 'DriverPackage')]
    [Alias('Profile')]
    [string]$CompareProfile = 'Default',

    [string[]]$Ignore = @(),

    [switch]$IgnoreEmptyDirectories,

    [switch]$AlignChildRoots,

    [switch]$Detailed,

    [switch]$Quiet,

    [switch]$AgentSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $repoRoot 'src\Tree.Compare\Tree.Compare.psd1') -Force

$quietFlag = $Quiet -or $AgentSummary
$alignBound = $PSBoundParameters.ContainsKey('AlignChildRoots')

$splat = @{
    PathA                   = $PathA
    PathB                   = $PathB
    Mode                    = $Mode
    Engine                  = $Engine
    CompareProfile          = $CompareProfile
    Ignore                  = $Ignore
    IgnoreEmptyDirectories  = $IgnoreEmptyDirectories
    Detailed                = $Detailed
    Quiet                   = $quietFlag
}
if ($alignBound) {
    $splat['AlignChildRoots'] = $AlignChildRoots
}

$result = Compare-TcTree @splat
$code = Get-TcCompareExitCode -Result $result

if ($AgentSummary) {
    Write-Output (Format-TcAgentSummary -Result $result)
    exit $code
}

Write-Output $result
exit $code
