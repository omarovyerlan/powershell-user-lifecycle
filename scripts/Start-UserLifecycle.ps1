<#
.SYNOPSIS
    Runs the user onboarding/offboarding process end to end.
.DESCRIPTION
    Loads settings, prepares the lab directory (copied from the seed on first run),
    processes the HR feed, writes a log and saves HTML + CSV reports.
.PARAMETER HRFile
    HR change CSV. Defaults to data/hr-changes.csv.
.PARAMETER ConfigPath
    Settings file. Defaults to config/settings.json.
.PARAMETER Reset
    Start again from the seed directory (deletes the working copy in output/).
.EXAMPLE
    ./scripts/Start-UserLifecycle.ps1 -WhatIf
    Dry run: shows what would change, writes a report, changes nothing.
.EXAMPLE
    ./scripts/Start-UserLifecycle.ps1
    Live run against the lab directory.
.EXAMPLE
    ./scripts/Start-UserLifecycle.ps1 -Reset -Verbose
    Reset the lab directory and run with detailed output.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$HRFile = (Join-Path $PSScriptRoot '..' 'data' 'hr-changes.csv'),

    [string]$ConfigPath = (Join-Path $PSScriptRoot '..' 'config' 'settings.json'),

    [switch]$Reset
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Name (Join-Path $root 'src' 'UserLifecycle' 'UserLifecycle.psd1') -Force

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$directoryPath = Join-Path $root $config.DirectoryPath

if ($Reset -and (Test-Path -Path $directoryPath)) {
    Remove-Item -Path $directoryPath -Force -WhatIf:$false
}

if (-not (Test-Path -Path $directoryPath)) {
    New-Item -ItemType Directory -Path (Split-Path -Path $directoryPath -Parent) -Force -WhatIf:$false | Out-Null
    Copy-Item -Path (Join-Path $root $config.SeedDirectoryPath) -Destination $directoryPath -WhatIf:$false
    Write-Information -MessageData "Lab directory created from seed: $directoryPath" -InformationAction Continue
}

$lifecycleParams = @{
    HRFile        = $HRFile
    DirectoryPath = $directoryPath
    Config        = $config
    LogPath       = Join-Path $root $config.LogPath
    WhatIf        = $WhatIfPreference
}
$results = Invoke-UserLifecycle @lifecycleParams

$report = $results | Export-LifecycleReport -OutputPath (Join-Path $root $config.ReportPath)

$results | Format-Table -Property EmployeeId, Name, Action, Status, UserName -AutoSize | Out-String | Write-Output
Write-Output "HTML report: $($report.HtmlPath)"
Write-Output "CSV report:  $($report.CsvPath)"
