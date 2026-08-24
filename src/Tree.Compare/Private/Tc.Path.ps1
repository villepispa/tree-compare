#Requires -Version 7.2

function ConvertTo-TcRelativeKey {
    <#
    .SYNOPSIS
        Normalize a full path to a dictionary key (forward slashes, lower-case).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$FullPath
    )

    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($FullPath)
    if ([string]::Equals($rootFull, $full, [StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }
    $rel = [IO.Path]::GetRelativePath($rootFull, $full)
    return ($rel.Replace('\', '/')).ToLowerInvariant()
}

function Get-TcIgnorePatterns {
    <#
    .SYNOPSIS
        Built-in ignore patterns for a named compare profile.

    .PARAMETER CompareProfile
        Default or DriverPackage. Alias: Profile.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [ValidateSet('Default', 'DriverPackage')]
        [Alias('Profile')]
        [string]$CompareProfile = 'Default'
    )

    if ($CompareProfile -eq 'DriverPackage') {
        return @(
            'Thumbs.db'
            'desktop.ini'
            '.DS_Store'
            '__MACOSX'
        )
    }
    return @()
}

function Test-TcIsIgnoredPath {
    <#
    .SYNOPSIS
        True when a relative path matches an ignore pattern (leaf, segment, or -like).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$RelPath,

        [string[]]$Patterns = @()
    )

    if ([string]::IsNullOrWhiteSpace($RelPath) -or @($Patterns).Count -eq 0) {
        return $false
    }

    $normalized = $RelPath.Replace('\', '/')
    $leaf = [IO.Path]::GetFileName($normalized)
    $parts = @($normalized -split '/')

    foreach ($pattern in @($Patterns)) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($leaf -like $pattern) { return $true }
        if ($normalized -like $pattern) { return $true }
        foreach ($part in $parts) {
            if ($part -like $pattern) { return $true }
        }
    }
    return $false
}

function Resolve-TcEffectiveRoot {
    <#
    .SYNOPSIS
        Optionally descend into a single child folder (zip-extract wrapper).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$AlignChildRoots
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if (-not $AlignChildRoots) {
        return $resolved
    }

    $dirs = @(
        Get-ChildItem -LiteralPath $resolved -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }
    )
    $files = @(Get-ChildItem -LiteralPath $resolved -Force -File -ErrorAction SilentlyContinue)
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) {
        return $dirs[0].FullName
    }
    return $resolved
}

function Test-TcIsReparsePoint {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    return [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}
