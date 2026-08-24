@{
    RootModule        = 'Tree.Compare.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '3c8e1f52-a9b4-4d06-8e7c-2b1f5a0d9c44'
    Author            = 'Ville Pispa'
    CompanyName       = 'Independent'
    Copyright         = '(c) 2026 Ville Pispa. MIT License.'
    Description       = 'Headless folder-tree identity compare (paths, length, optional timestamp, SHA256). Speed vs Accuracy modes for vendor package trees.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'ConvertTo-TcRelativeKey'
        'Get-TcIgnorePatterns'
        'Test-TcIsIgnoredPath'
        'Resolve-TcEffectiveRoot'
        'New-TcFileDictionary'
        'Get-TcFileSha256'
        'Compare-TcTree'
        'Get-TcCompareExitCode'
        'Format-TcAgentSummary'
    )
    PrivateData       = @{
        PSData = @{
            Tags         = @('Compare', 'Hash', 'SHA256', 'Folder', 'Driver', 'Package', 'PowerShell')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = 'v0.1.0 — Native engine; Speed/Accuracy; DriverPackage profile.'
        }
    }
}
