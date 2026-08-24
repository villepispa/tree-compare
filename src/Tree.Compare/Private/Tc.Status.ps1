#Requires -Version 7.2

function Write-TcStatus {
    <#
    .SYNOPSIS
        Host status line for a compare step. No-op when Quiet.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Step,

        [Parameter(Mandatory)]
        [ValidateSet('BANNER', 'START', 'DONE', 'DETAIL')]
        [string]$Phase,

        [string]$Message = '',

        [switch]$Quiet
    )

    if ($Quiet) { return }
    $text = if ($Phase -eq 'BANNER') {
        "TC $Message"
    }
    else {
        "TC $Step $Phase $Message"
    }
    Write-Host $text.Trim()
}

function Get-TcCompareExitCode {
    <#
    .SYNOPSIS
        Map a compare result Verdict to a process exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    switch ([string]$Result.Verdict) {
        'Identical' { return 0 }
        'TimestampSuspect' { return 1 }
        'Different' { return 2 }
        default { return 3 }
    }
}

function Format-TcAgentSummary {
    <#
    .SYNOPSIS
        One success-stream line for agents (TC-COMPARE-OK | TC-COMPARE-FAIL).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    $token = if ($Result.Verdict -eq 'Error') {
        'TC-COMPARE-FAIL'
    }
    else {
        'TC-COMPARE-OK'
    }

    return (
        '{0} verdict={1} mode={2} engine={3} profile={4} leftOnly={5} rightOnly={6} length={7} timestamp={8} hash={9} hashed={10} contentEqual={11}' -f
        $token,
        $Result.Verdict,
        $Result.Mode,
        $Result.Engine,
        $Result.Profile,
        $Result.LeftOnlyCount,
        $Result.RightOnlyCount,
        $Result.LengthMismatchCount,
        $Result.TimestampMismatchCount,
        $Result.HashMismatchCount,
        $Result.HashedCount,
        $Result.ContentEqual
    )
}
