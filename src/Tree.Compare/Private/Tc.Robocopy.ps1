#Requires -Version 7.2

function Get-TcRobocopyExe {
    <#
    .SYNOPSIS
        Resolve Windows robocopy.exe (System32). $null if missing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $candidate = Join-Path $env:SystemRoot 'System32\robocopy.exe'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }
    return $null
}

function ConvertFrom-TcRobocopyLog {
    <#
    .SYNOPSIS
        Map robocopy /L UNILOG class lines to Tree.Compare path buckets.

    .DESCRIPTION
        Extra/New → path-only, Changed → length, Tweaked/Newer/Older →
        timestamp, Same → identical metadata. Directory header lines set the
        current relative folder so leaf names become keys.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestRoot
    )

    $sourceRoot = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/')
    $destRoot = [IO.Path]::GetFullPath($DestRoot).TrimEnd('\', '/')

    $leftOnly = [System.Collections.Generic.List[string]]::new()
    $rightOnly = [System.Collections.Generic.List[string]]::new()
    $lengthMismatch = [System.Collections.Generic.List[string]]::new()
    $timestampMismatch = [System.Collections.Generic.List[string]]::new()
    $same = [System.Collections.Generic.List[string]]::new()
    $extraDirs = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    $currentRel = ''
    $classNames = @(
        '*EXTRA Dir'
        '*EXTRA File'
        'EXTRA Dir'
        'EXTRA File'
        'New File'
        'New Dir'
        'Changed'
        'Tweaked'
        'Newer'
        'Older'
        'Same'
    )

    foreach ($raw in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $trimmed = $raw.TrimStart()

        $matchedClass = $null
        foreach ($name in $classNames) {
            if ($trimmed.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)) {
                $matchedClass = $name
                break
            }
        }

        if ($matchedClass) {
            $rest = $trimmed.Substring($matchedClass.Length).TrimStart()
            if ($rest -notmatch '^(?<Size>-?\d+)\s+(?<Name>.+)$') {
                continue
            }
            $itemName = $Matches.Name.Trim()
            $canon = ($matchedClass.TrimStart('*')).Trim()
            $key = ConvertTo-TcRobocopyItemKey -Name $itemName -CurrentRel $currentRel `
                -SourceRoot $sourceRoot -DestRoot $destRoot -ClassName $canon
            if ([string]::IsNullOrWhiteSpace($key)) { continue }

            switch -Regex ($canon) {
                '^EXTRA Dir$' {
                    Add-TcRobocopyKey -Set $seen -List $rightOnly -Key $key
                    if (-not $extraDirs.Contains($key)) {
                        $extraDirs.Add($key)
                    }
                }
                '^EXTRA File$' {
                    Add-TcRobocopyKey -Set $seen -List $rightOnly -Key $key
                }
                '^New Dir$' {
                    Add-TcRobocopyKey -Set $seen -List $leftOnly -Key $key
                    $currentRel = $key
                }
                '^New File$' {
                    Add-TcRobocopyKey -Set $seen -List $leftOnly -Key $key
                }
                '^Changed$' {
                    Add-TcRobocopyKey -Set $seen -List $lengthMismatch -Key $key
                }
                '^(Tweaked|Newer|Older)$' {
                    Add-TcRobocopyKey -Set $seen -List $timestampMismatch -Key $key
                }
                '^Same$' {
                    Add-TcRobocopyKey -Set $seen -List $same -Key $key
                }
            }
            continue
        }

        if ($trimmed -match '^(?<Count>\d+)\s+(?<Path>.+\\)\s*$') {
            $headerPath = $Matches.Path.Trim()
            if ([IO.Path]::IsPathRooted($headerPath)) {
                $rel = (ConvertTo-TcRelativeKey -Root $sourceRoot -FullPath $headerPath).Trim('/')
                if ($rel -eq '.') {
                    $rel = ''
                }
                $currentRel = $rel
            }
        }
    }

    return [pscustomobject]@{
        LeftOnly           = @($leftOnly)
        RightOnly          = @($rightOnly)
        LengthMismatch     = @($lengthMismatch)
        TimestampMismatch  = @($timestampMismatch)
        Same               = @($same)
        ExtraDirs          = @($extraDirs)
    }
}

function ConvertTo-TcRobocopyItemKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$CurrentRel,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestRoot,

        [Parameter(Mandatory)]
        [string]$ClassName
    )

    if ([IO.Path]::IsPathRooted($Name)) {
        $root = if ($ClassName -match '^EXTRA') { $DestRoot } else { $SourceRoot }
        return (ConvertTo-TcRelativeKey -Root $root -FullPath $Name).Trim('/')
    }

    $leaf = ($Name.Replace('\', '/')).Trim('/')
    if ([string]::IsNullOrWhiteSpace($CurrentRel) -or $CurrentRel -eq '.') {
        return $leaf.ToLowerInvariant()
    }
    return ($CurrentRel.Trim('/') + '/' + $leaf).ToLowerInvariant()
}

function Add-TcRobocopyKey {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$Set,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$List,

        [Parameter(Mandatory)]
        [string]$Key
    )

    if ($Set.Add($Key)) {
        $List.Add($Key)
    }
}

function Get-TcPathFromRelKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return [IO.Path]::GetFullPath($Root)
    }
    $rel = $Key.Replace('/', [IO.Path]::DirectorySeparatorChar)
    return [IO.Path]::GetFullPath((Join-Path $Root $rel))
}

function Expand-TcRobocopyExtraDirs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DestRoot,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ExtraDirs,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$RightOnly,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$Seen,

        [string[]]$Patterns = @(),

        [switch]$IgnoreEmptyDirectories
    )

    foreach ($dirKey in @($ExtraDirs)) {
        if (Test-TcIsIgnoredPath -RelPath $dirKey -Patterns $Patterns) { continue }
        $full = Get-TcPathFromRelKey -Root $DestRoot -Key $dirKey
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $items = @(
            Get-ChildItem -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
        )
        foreach ($item in $items) {
            if (Test-TcIsReparsePoint -Item $item) { continue }
            $key = ConvertTo-TcRelativeKey -Root $DestRoot -FullPath $item.FullName
            if ([string]::IsNullOrWhiteSpace($key)) { continue }
            if (Test-TcIsIgnoredPath -RelPath $key -Patterns $Patterns) { continue }
            if ($item.PSIsContainer -and $IgnoreEmptyDirectories) { continue }
            Add-TcRobocopyKey -Set $Seen -List $RightOnly -Key $key
        }
    }
}

function Invoke-TcRobocopyList {
    <#
    .SYNOPSIS
        List-only robocopy (/L /FFT /DST /IS /IT /XJ) into a parsed listing.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$DestRoot
    )

    $exe = Get-TcRobocopyExe
    if (-not $exe) {
        return [pscustomobject]@{
            Error   = 'robocopy.exe not found under System32. Engine Robocopy/Hybrid requires Windows robocopy.'
            Parsed  = $null
            ExitCode = 16
        }
    }

    $log = Join-Path ([IO.Path]::GetTempPath()) ('tc-robo-' + [guid]::NewGuid().ToString('n') + '.log')
    $srcArg = $SourceRoot.TrimEnd('\', '/') + '\'
    $dstArg = $DestRoot.TrimEnd('\', '/') + '\'
    $argList = @(
        $srcArg
        $dstArg
        '/L'
        '/E'
        '/FFT'
        '/DST'
        '/IS'
        '/IT'
        '/XJ'
        '/NJH'
        '/NJS'
        '/NP'
        '/BYTES'
        '/R:0'
        '/W:0'
        "/UNILOG:$log"
    )

    try {
        & $exe @argList 2>&1 | Out-Null
        $code = $LASTEXITCODE
        if ($code -ge 8) {
            return [pscustomobject]@{
                Error    = "robocopy listing failed (exit $code)."
                Parsed   = $null
                ExitCode = $code
            }
        }
        if (-not (Test-Path -LiteralPath $log)) {
            return [pscustomobject]@{
                Error    = 'robocopy produced no UNILOG.'
                Parsed   = $null
                ExitCode = $code
            }
        }
        $lines = @(
            Get-Content -LiteralPath $log -Encoding unicode |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $parsed = ConvertFrom-TcRobocopyLog -Lines $lines -SourceRoot $SourceRoot -DestRoot $DestRoot
        return [pscustomobject]@{
            Error    = $null
            Parsed   = $parsed
            ExitCode = $code
        }
    }
    finally {
        if (Test-Path -LiteralPath $log) {
            Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-TcRobocopyTreeCompare {
    <#
    .SYNOPSIS
        Speed compare via robocopy listing; Hybrid Accuracy hashes same-length pairs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$PathA,

        [Parameter(Mandatory)]
        [string]$PathB,

        [Parameter(Mandatory)]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$Engine,

        [Parameter(Mandatory)]
        [string]$CompareProfile,

        [string[]]$Ignore = @(),

        [switch]$IgnoreEmptyDirectories,

        [switch]$AlignChildRoots,

        [switch]$Detailed,

        [switch]$Quiet,

        [Parameter(Mandatory)]
        [datetime]$Started
    )

    $effA = Resolve-TcEffectiveRoot -Path $PathA -AlignChildRoots:$AlignChildRoots
    $effB = Resolve-TcEffectiveRoot -Path $PathB -AlignChildRoots:$AlignChildRoots
    $patterns = @()
    $patterns += @(Get-TcIgnorePatterns -CompareProfile $CompareProfile)
    $patterns += @($Ignore)

    Write-TcStatus -Step Robocopy -Phase START -Quiet:$Quiet -Message '/L /FFT /DST'
    $listing = Invoke-TcRobocopyList -SourceRoot $effA -DestRoot $effB
    if ($listing.Error) {
        Write-TcStatus -Step Robocopy -Phase DONE -Quiet:$Quiet -Message $listing.Error
        return $null, $listing.Error
    }
    Write-TcStatus -Step Robocopy -Phase DONE -Quiet:$Quiet -Message ("exit={0}" -f $listing.ExitCode)

    $parsed = $listing.Parsed
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $leftOnly = [System.Collections.Generic.List[string]]::new()
    $rightOnly = [System.Collections.Generic.List[string]]::new()
    $lengthMismatch = [System.Collections.Generic.List[string]]::new()
    $timestampMismatch = [System.Collections.Generic.List[string]]::new()
    $same = [System.Collections.Generic.List[string]]::new()

    foreach ($key in @($parsed.LeftOnly)) {
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }
        Add-TcRobocopyKey -Set $seen -List $leftOnly -Key $key
    }
    foreach ($key in @($parsed.RightOnly)) {
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }
        Add-TcRobocopyKey -Set $seen -List $rightOnly -Key $key
    }
    foreach ($key in @($parsed.LengthMismatch)) {
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }
        Add-TcRobocopyKey -Set $seen -List $lengthMismatch -Key $key
    }
    foreach ($key in @($parsed.TimestampMismatch)) {
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }
        Add-TcRobocopyKey -Set $seen -List $timestampMismatch -Key $key
    }
    foreach ($key in @($parsed.Same)) {
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }
        Add-TcRobocopyKey -Set $seen -List $same -Key $key
    }

    Expand-TcRobocopyExtraDirs -DestRoot $effB -ExtraDirs @($parsed.ExtraDirs) `
        -RightOnly $rightOnly -Seen $seen -Patterns $patterns `
        -IgnoreEmptyDirectories:$IgnoreEmptyDirectories

    if ($IgnoreEmptyDirectories) {
        $leftKeep = [System.Collections.Generic.List[string]]::new()
        foreach ($key in @($leftOnly)) {
            $itemPath = Get-TcPathFromRelKey -Root $effA -Key $key
            if ((Test-Path -LiteralPath $itemPath) -and (Get-Item -LiteralPath $itemPath).PSIsContainer) {
                continue
            }
            $leftKeep.Add($key)
        }
        $leftOnly = $leftKeep
        $rightKeep = [System.Collections.Generic.List[string]]::new()
        foreach ($key in @($rightOnly)) {
            $itemPath = Get-TcPathFromRelKey -Root $effB -Key $key
            if ((Test-Path -LiteralPath $itemPath) -and (Get-Item -LiteralPath $itemPath).PSIsContainer) {
                continue
            }
            $rightKeep.Add($key)
        }
        $rightOnly = $rightKeep
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

    Write-TcStatus -Step Length -Phase DONE -Quiet:$Quiet -Message (
        "mismatch={0} sameLength={1}" -f $lengthMismatch.Count, ($same.Count + $timestampMismatch.Count)
    )
    if ($Detailed) {
        foreach ($p in $lengthMismatch) {
            Write-TcStatus -Step Length -Phase DETAIL -Quiet:$Quiet -Message $p
        }
    }

    $hashMismatch = [System.Collections.Generic.List[string]]::new()
    $hashed = 0
    $hashSkipped = 0
    $comparedFiles = $same.Count + $lengthMismatch.Count + $timestampMismatch.Count

    if ($Mode -eq 'Speed') {
        $hashSkipped = $same.Count + $timestampMismatch.Count
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
        $candidates = @($same) + @($timestampMismatch)
        $timestampMismatch.Clear()
        foreach ($key in $candidates) {
            $leftPath = Get-TcPathFromRelKey -Root $effA -Key $key
            $rightPath = Get-TcPathFromRelKey -Root $effB -Key $key
            $ha = Get-TcFileSha256 -Path $leftPath
            $hb = Get-TcFileSha256 -Path $rightPath
            $hashed += 2
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
        ElapsedMs              = [int]((Get-Date) - $Started).TotalMilliseconds
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

    return $result, $null
}
