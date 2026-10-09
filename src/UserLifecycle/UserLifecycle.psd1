@{
    RootModule        = 'UserLifecycle.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '6f3c2b1e-8a4d-4c7e-9b2a-1d5e7f9a3c41'
    Author            = 'Yerlan Omarov'
    Description       = 'Automates user onboarding and offboarding from an HR feed against a lab directory (JSON), with logging and HTML/CSV reports.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Import-HRChange'
        'New-LabUser'
        'Disable-LabUser'
        'Invoke-UserLifecycle'
        'Export-LifecycleReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('Onboarding', 'Offboarding', 'IAM', 'Automation', 'SysAdmin')
            ProjectUri = 'https://github.com/omarovyerlan/powershell-user-lifecycle'
        }
    }
}
