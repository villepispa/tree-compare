#Requires -Version 7.2

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in @($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'ConvertTo-TcRelativeKey'
    'Get-TcIgnorePatterns'
    'Test-TcIsIgnoredPath'
    'Resolve-TcEffectiveRoot'
    'New-TcFileDictionary'
    'Get-TcFileSha256'
    'ConvertFrom-TcRobocopyLog'
    'Compare-TcTree'
    'Get-TcCompareExitCode'
    'Format-TcAgentSummary'
)
