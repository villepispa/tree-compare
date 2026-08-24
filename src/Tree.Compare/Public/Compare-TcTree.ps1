#Requires -Version 7.2

function Compare-TcTree {
    <#
    .SYNOPSIS
        Compare two folder trees. Speed uses metadata; Accuracy hashes matching lengths.

    .DESCRIPTION
        Walks each root once into a Hashtable (O(1) lookups). Cascade: Paths,
        Length, Timestamp (Speed only), SHA256 (Accuracy only). Timestamp never
        decides content identity — Speed time-only diffs yield TimestampSuspect.

    .PARAMETER PathA
        Left tree root.

    .PARAMETER PathB
        Right tree root.

    .PARAMETER Mode
        Speed (default): skip hash; treat timestamp mismatch as suspect.
        Accuracy: skip timestamp; hash every same-path same-length file pair.

    .PARAMETER Engine
        Native (v0.1). Robocopy and Hybrid throw (product issue TC-002).

    .PARAMETER CompareProfile
        Default or DriverPackage (ignore junk + align single child root).
        Alias: Profile.

    .PARAMETER Ignore
        Extra -like patterns (leaf, path, or segment).

    .PARAMETER IgnoreEmptyDirectories
        Omit directory entries from the path set.

    .PARAMETER AlignChildRoots
        Descend when a root has exactly one child folder and no files.
        Default true for DriverPackage.

    .PARAMETER Detailed
        Include per-path lists on the result and print them unless Quiet.

    .PARAMETER Quiet
        Suppress host status lines.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
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

        [switch]$Quiet
    )

    $started = Get-Date
    $align = $AlignChildRoots
    if ($CompareProfile -eq 'DriverPackage' -and -not $PSBoundParameters.ContainsKey('AlignChildRoots')) {
        $align = $true
    }

    $errorResult = {
        param([string]$Message)
        return [pscustomobject]@{
            Verdict                 = 'Error'
            ContentEqual            = $false
            TimestampOnly           = $false
            Mode                    = $Mode
            Engine                  = $Engine
            Profile                 = $CompareProfile
            PathA                   = $PathA
            PathB                   = $PathB
            LeftOnlyCount           = 0
            RightOnlyCount          = 0
            LengthMismatchCount     = 0
            TimestampMismatchCount  = 0
            HashMismatchCount       = 0
            HashedCount             = 0
            HashSkippedCount        = 0
            ComparedFileCount       = 0
            Error                   = $Message
            ElapsedMs               = [int]((Get-Date) - $started).TotalMilliseconds
            LeftOnly                = @()
            RightOnly               = @()
            LengthMismatch          = @()
            TimestampMismatch       = @()
            HashMismatch            = @()
        }
    }

    if ($Engine -ne 'Native') {
        $msg = "Engine '$Engine' is not implemented in v0.1. See product issue TC-002. Use -Engine Native."
        Write-TcStatus -Step Engine -Phase BANNER -Message $msg -Quiet:$Quiet
        return & $errorResult $msg
    }

    if (-not (Test-Path -LiteralPath $PathA)) {
        return & $errorResult "PathA not found: $PathA"
    }
    if (-not (Test-Path -LiteralPath $PathB)) {
        return & $errorResult "PathB not found: $PathB"
    }

    Write-TcStatus -Step Mode -Phase BANNER -Quiet:$Quiet -Message (
        "mode=$Mode engine=$Engine profile=$CompareProfile alignChildRoots=$align"
    )

    Write-TcStatus -Step DictionaryA -Phase START -Quiet:$Quiet
    $dictA = New-TcFileDictionary -Path $PathA -CompareProfile $CompareProfile -Ignore $Ignore `
        -IgnoreEmptyDirectories:$IgnoreEmptyDirectories -AlignChildRoots:$align
    Write-TcStatus -Step DictionaryA -Phase DONE -Quiet:$Quiet -Message ("entries={0}" -f $dictA.Count)

    Write-TcStatus -Step DictionaryB -Phase START -Quiet:$Quiet
    $dictB = New-TcFileDictionary -Path $PathB -CompareProfile $CompareProfile -Ignore $Ignore `
        -IgnoreEmptyDirectories:$IgnoreEmptyDirectories -AlignChildRoots:$align
    Write-TcStatus -Step DictionaryB -Phase DONE -Quiet:$Quiet -Message ("entries={0}" -f $dictB.Count)

    Write-TcStatus -Step Paths -Phase START -Quiet:$Quiet
    $leftOnly = [System.Collections.Generic.List[string]]::new()
    $rightOnly = [System.Collections.Generic.List[string]]::new()
    foreach ($key in @($dictA.Keys)) {
        if (-not $dictB.ContainsKey($key)) { $leftOnly.Add($key) }
    }
    foreach ($key in @($dictB.Keys)) {
        if (-not $dictA.ContainsKey($key)) { $rightOnly.Add($key) }
    }
    Write-TcStatus -Step Paths -Phase DONE -Quiet:$Quiet -Message (
        "leftOnly={0} rightOnly={1}" -f $leftOnly.Count, $rightOnly.Count
    )
    if ($Detailed) {
        foreach ($p in $leftOnly) {
            Write-TcStatus -Step Paths -Phase DETAIL -Quiet:$Quiet -Message "leftOnly $p"
        }
        foreach ($p in $rightOnly) {
            Write-TcStatus -Step Paths -Phase DETAIL -Quiet:$Quiet -Message "rightOnly $p"
        }
    }

    $lengthMismatch = [System.Collections.Generic.List[string]]::new()
    $timestampMismatch = [System.Collections.Generic.List[string]]::new()
    $hashMismatch = [System.Collections.Generic.List[string]]::new()
    $candidates = [System.Collections.Generic.List[string]]::new()
    $comparedFiles = 0

    Write-TcStatus -Step Length -Phase START -Quiet:$Quiet
    foreach ($key in @($dictA.Keys)) {
        if (-not $dictB.ContainsKey($key)) { continue }
        $left = $dictA[$key]
        $right = $dictB[$key]
        if ($left.IsDirectory -or $right.IsDirectory) {
            if ($left.IsDirectory -ne $right.IsDirectory) {
                $lengthMismatch.Add($key)
            }
            continue
        }
        $comparedFiles++
        if ($left.Length -ne $right.Length) {
            $lengthMismatch.Add($key)
            continue
        }
        $candidates.Add($key)
    }
    Write-TcStatus -Step Length -Phase DONE -Quiet:$Quiet -Message (
        "mismatch={0} sameLength={1}" -f $lengthMismatch.Count, $candidates.Count
    )
    if ($Detailed) {
        foreach ($p in $lengthMismatch) {
            Write-TcStatus -Step Length -Phase DETAIL -Quiet:$Quiet -Message $p
        }
    }

    $hashed = 0
    $hashSkipped = 0

    if ($Mode -eq 'Speed') {
        Write-TcStatus -Step Timestamp -Phase START -Quiet:$Quiet
        $still = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $candidates) {
            $left = $dictA[$key]
            $right = $dictB[$key]
            if ($left.LastWriteTimeUtc -ne $right.LastWriteTimeUtc) {
                $timestampMismatch.Add($key)
                $hashSkipped++
                continue
            }
            $hashSkipped++
            $still.Add($key)
        }
        Write-TcStatus -Step Timestamp -Phase DONE -Quiet:$Quiet -Message (
            "mismatch={0} skippedHash={1}" -f $timestampMismatch.Count, $hashSkipped
        )
        if ($Detailed) {
            foreach ($p in $timestampMismatch) {
                Write-TcStatus -Step Timestamp -Phase DETAIL -Quiet:$Quiet -Message $p
            }
        }
        Write-TcStatus -Step Hash -Phase DONE -Quiet:$Quiet -Message 'skipped (Speed)'
    }
    else {
        Write-TcStatus -Step Timestamp -Phase DONE -Quiet:$Quiet -Message 'skipped (Accuracy)'
        Write-TcStatus -Step Hash -Phase START -Quiet:$Quiet
        foreach ($key in $candidates) {
            $left = $dictA[$key]
            $right = $dictB[$key]
            $ha = Get-TcFileSha256 -Path $left.FullPath
            $hb = Get-TcFileSha256 -Path $right.FullPath
            $hashed += 2
            $left.Hash = $ha
            $right.Hash = $hb
            if ($ha -ne $hb) {
                $hashMismatch.Add($key)
            }
        }
        Write-TcStatus -Step Hash -Phase DONE -Quiet:$Quiet -Message (
            "hashedFiles={0} mismatch={1}" -f $hashed, $hashMismatch.Count
        )
        if ($Detailed) {
            foreach ($p in $hashMismatch) {
                Write-TcStatus -Step Hash -Phase DETAIL -Quiet:$Quiet -Message $p
            }
        }
    }

    $pathDiff = $leftOnly.Count + $rightOnly.Count
    $contentDiff = $lengthMismatch.Count + $hashMismatch.Count
    $timestampOnly = ($pathDiff -eq 0 -and $contentDiff -eq 0 -and $timestampMismatch.Count -gt 0)

    if ($pathDiff -eq 0 -and $contentDiff -eq 0 -and $timestampMismatch.Count -eq 0) {
        $verdict = 'Identical'
        $contentEqual = $true
    }
    elseif ($timestampOnly) {
        $verdict = 'TimestampSuspect'
        $contentEqual = $false
    }
    else {
        $verdict = 'Different'
        $contentEqual = $false
    }

    $result = [pscustomobject]@{
        Verdict                = $verdict
        ContentEqual           = $contentEqual
        TimestampOnly          = $timestampOnly
        Mode                   = $Mode
        Engine                 = $Engine
        Profile                = $CompareProfile
        PathA                  = (Resolve-Path -LiteralPath $PathA).Path
        PathB                  = (Resolve-Path -LiteralPath $PathB).Path
        LeftOnlyCount          = $leftOnly.Count
        RightOnlyCount         = $rightOnly.Count
        LengthMismatchCount    = $lengthMismatch.Count
        TimestampMismatchCount = $timestampMismatch.Count
        HashMismatchCount      = $hashMismatch.Count
        HashedCount            = $hashed
        HashSkippedCount       = $hashSkipped
        ComparedFileCount      = $comparedFiles
        Error                  = $null
        ElapsedMs              = [int]((Get-Date) - $started).TotalMilliseconds
        LeftOnly               = @($leftOnly)
        RightOnly              = @($rightOnly)
        LengthMismatch         = @($lengthMismatch)
        TimestampMismatch      = @($timestampMismatch)
        HashMismatch           = @($hashMismatch)
    }

    Write-TcStatus -Step Report -Phase DONE -Quiet:$Quiet -Message (
        "verdict={0} contentEqual={1} leftOnly={2} rightOnly={3} length={4} timestamp={5} hash={6}" -f
        $result.Verdict,
        $result.ContentEqual,
        $result.LeftOnlyCount,
        $result.RightOnlyCount,
        $result.LengthMismatchCount,
        $result.TimestampMismatchCount,
        $result.HashMismatchCount
    )

    return $result
}
