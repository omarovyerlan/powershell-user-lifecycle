function Disable-LabUser {
    <#
    .SYNOPSIS
        Offboards a user in the lab directory for a Terminate event.
    .DESCRIPTION
        Disables the account, removes all group memberships (so access is revoked),
        moves the account to the Disabled OU and records the date.
        Supports -WhatIf: in a dry run the directory is not changed.
    .PARAMETER Change
        A Terminate record from Import-HRChange.
    .PARAMETER Directory
        The in-memory lab directory (from Read-LabDirectory). It is modified in place.
    .PARAMETER Config
        Settings object (DisabledOU).
    .EXAMPLE
        Disable-LabUser -Change $termination -Directory $directory -Config $config
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [object]$Change,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Directory,

        [Parameter(Mandatory)]
        [object]$Config
    )

    $user = $Directory | Where-Object { $_.EmployeeId -eq $Change.EmployeeId } | Select-Object -First 1
    if (-not $user) {
        Write-LifecycleLog -Message "Terminate $($Change.EmployeeId): no account found." -Level Warning
        return ConvertTo-LifecycleResult -Change $Change -Status 'NotFound' -Details 'No account found for this EmployeeId'
    }

    $name = $user.DisplayName
    if (-not $user.Enabled) {
        Write-LifecycleLog -Message "Terminate $($Change.EmployeeId): $($user.SamAccountName) is already disabled, skipping."
        return ConvertTo-LifecycleResult -Change $Change -Status 'Skipped' -UserName $user.SamAccountName -Name $name -Details 'Account already disabled'
    }

    $removedGroups = @($user.Groups)
    $groupList = $removedGroups -join ', '

    if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Disable account and remove from $($removedGroups.Count) group(s)")) {
        # Add-Member -Force sets the value whether or not the property already exists.
        $user | Add-Member -NotePropertyName Enabled    -NotePropertyValue $false -Force
        $user | Add-Member -NotePropertyName Groups     -NotePropertyValue @() -Force
        $user | Add-Member -NotePropertyName OU         -NotePropertyValue $Config.DisabledOU -Force
        $user | Add-Member -NotePropertyName DisabledOn -NotePropertyValue (Get-Date -Format 'yyyy-MM-dd') -Force

        Write-LifecycleLog -Message "Disabled $($user.SamAccountName) ($($Change.EmployeeId)); removed groups: $groupList"
        return ConvertTo-LifecycleResult -Change $Change -Status 'Disabled' -UserName $user.SamAccountName -Name $name -Details "Removed from: $groupList"
    }

    return ConvertTo-LifecycleResult -Change $Change -Status 'WhatIf' -UserName $user.SamAccountName -Name $name -Details "Would disable account; remove from: $groupList"
}
