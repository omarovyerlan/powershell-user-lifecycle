function Invoke-UserLifecycle {
    <#
    .SYNOPSIS
        Processes an HR change feed: onboards new hires and offboards leavers.
    .DESCRIPTION
        1. Loads the lab directory and validates the HR feed.
        2. Changes with a future EffectiveDate are reported as Scheduled and left for a later run.
        3. Hire -> New-LabUser, Terminate -> Disable-LabUser.
        4. A failure on one record is logged and the run continues with the next one.
        5. The directory is saved only if something changed (and not during -WhatIf).
    .PARAMETER HRFile
        Path to the HR change CSV.
    .PARAMETER DirectoryPath
        Path to the lab directory JSON file.
    .PARAMETER Config
        Settings object loaded from config/settings.json.
    .PARAMETER LogPath
        Optional folder for the run log. A new timestamped log file is created per run.
    .PARAMETER AsOfDate
        Treat this date as "today" when deciding which changes are due. Defaults to today.
    .EXAMPLE
        $config = Get-Content ./config/settings.json -Raw | ConvertFrom-Json
        Invoke-UserLifecycle -HRFile ./data/hr-changes.csv -DirectoryPath ./output/directory.json -Config $config -WhatIf
    .OUTPUTS
        UserLifecycle.Result objects, one per HR record.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$HRFile,

        [Parameter(Mandatory)]
        [string]$DirectoryPath,

        [Parameter(Mandatory)]
        [object]$Config,

        [string]$LogPath,

        [datetime]$AsOfDate = (Get-Date).Date
    )

    if ($LogPath) {
        if (-not (Test-Path -Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force -WhatIf:$false | Out-Null
        }
        $script:LogFile = Join-Path $LogPath ('lifecycle-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    else {
        $script:LogFile = $null
    }

    $mode = if ($WhatIfPreference) { 'DRY RUN (WhatIf)' } else { 'LIVE' }
    Write-LifecycleLog -Message "Run started in $mode mode. HR file: $HRFile; as of $($AsOfDate.ToString('yyyy-MM-dd'))"

    $directory = Read-LabDirectory -Path $DirectoryPath
    $changes = @(Import-HRChange -Path $HRFile)
    Write-LifecycleLog -Message "Loaded $($directory.Count) account(s) and $($changes.Count) valid HR change(s)."

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($change in $changes) {
        if ($change.EffectiveDate.Date -gt $AsOfDate.Date) {
            $results.Add((ConvertTo-LifecycleResult -Change $change -Status 'Scheduled' -Details "Effective $($change.EffectiveDate.ToString('yyyy-MM-dd'))"))
            continue
        }

        try {
            $result = switch ($change.Action) {
                'Hire'      { New-LabUser     -Change $change -Directory $directory -Config $Config -WhatIf:$WhatIfPreference }
                'Terminate' { Disable-LabUser -Change $change -Directory $directory -Config $Config -WhatIf:$WhatIfPreference }
            }
            $results.Add($result)
        }
        catch {
            Write-LifecycleLog -Message "$($change.Action) $($change.EmployeeId) failed: $($_.Exception.Message)" -Level Error
            $results.Add((ConvertTo-LifecycleResult -Change $change -Status 'Failed' -Details $_.Exception.Message))
        }
    }

    $changedCount = @($results | Where-Object { $_.Status -in 'Created', 'Disabled' }).Count
    if ($changedCount -gt 0 -and $PSCmdlet.ShouldProcess($DirectoryPath, "Save $changedCount change(s) to directory")) {
        Save-LabDirectory -Path $DirectoryPath -Users $directory
        Write-LifecycleLog -Message "Saved $changedCount change(s) to $DirectoryPath."
    }

    $summary = ($results | Group-Object -Property Status | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }) -join ', '
    Write-LifecycleLog -Message "Run finished. $summary"

    return $results.ToArray()
}
