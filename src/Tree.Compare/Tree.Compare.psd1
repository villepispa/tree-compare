@{
    RootModule        = 'Tree.Compare.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '3c8e1f52-a9b4-4d06-8e7c-2b1f5a0d9c44'
    Author            = 'Ville Pispa'
    CompanyName       = 'Independent'
    Copyright         = '(c) 2026 Ville Pispa. MIT License.'
    Description       = 'Headless folder-tree identity compare (Native, Robocopy, Hybrid). Speed vs Accuracy; SHA256 in Accuracy for vendor package trees.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
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
    PrivateData       = @{
        PSData = @{
            Tags         = @('Compare', 'Hash', 'SHA256', 'Folder', 'Driver', 'Package', 'PowerShell', 'Robocopy')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'v0.2.0 — Robocopy and Hybrid engines (TC-002).'
        }
    }
}
