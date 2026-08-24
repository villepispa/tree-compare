#Requires -Version 7.2

function New-TcFileDictionary {
    <#
    .SYNOPSIS
        Walk a folder once into a Hashtable keyed by normalized relative path.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Default', 'DriverPackage')]
        [Alias('Profile')]
        [string]$CompareProfile = 'Default',

        [string[]]$Ignore = @(),

        [switch]$IgnoreEmptyDirectories,

        [switch]$AlignChildRoots
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }

    $effective = Resolve-TcEffectiveRoot -Path $Path -AlignChildRoots:$AlignChildRoots
    $patterns = @()
    $patterns += @(Get-TcIgnorePatterns -CompareProfile $CompareProfile)
    $patterns += @($Ignore)

    $map = @{}
    $items = @(
        Get-ChildItem -LiteralPath $effective -Recurse -Force -ErrorAction SilentlyContinue
    )

    foreach ($item in $items) {
        if (Test-TcIsReparsePoint -Item $item) { continue }
        $key = ConvertTo-TcRelativeKey -Root $effective -FullPath $item.FullName
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        if (Test-TcIsIgnoredPath -RelPath $key -Patterns $patterns) { continue }

        $isDir = [bool]$item.PSIsContainer
        if ($isDir -and $IgnoreEmptyDirectories) { continue }

        $length = 0L
        $stamp = $item.LastWriteTimeUtc
        if (-not $isDir) {
            $length = [int64]$item.Length
        }

        $map[$key] = [pscustomobject]@{
            Key              = $key
            RelPath          = $key
            FullPath         = $item.FullName
            Length           = $length
            LastWriteTimeUtc = $stamp
            Hash             = $null
            IsDirectory      = $isDir
            Root             = $effective
        }
    }

    return $map
}

function Get-TcFileSha256 {
    <#
    .SYNOPSIS
        SHA256 hex (lower-case) of a file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
