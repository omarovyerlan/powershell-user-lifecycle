function New-LabUser {
    <#
    .SYNOPSIS
        Creates a user account in the lab directory for a Hire event.
    .DESCRIPTION
        Generates a unique username and email, places the user in the department OU and
        assigns default groups plus department groups from the configuration.
        Supports -WhatIf: in a dry run the directory is not changed.
    .PARAMETER Change
        A Hire record from Import-HRChange.
    .PARAMETER Directory
        The in-memory lab directory (from Read-LabDirectory). It is modified in place.
    .PARAMETER Config
        Settings object (Domain, UsersOU, DefaultGroups, DepartmentGroups).
    .EXAMPLE
        New-LabUser -Change $hire -Directory $directory -Config $config -WhatIf
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

    $existing = $Directory | Where-Object { $_.EmployeeId -eq $Change.EmployeeId } | Select-Object -First 1
    if ($existing) {
        Write-LifecycleLog -Message "Hire $($Change.EmployeeId): account already exists ($($existing.SamAccountName)), skipping." -Level Warning
        return ConvertTo-LifecycleResult -Change $Change -Status 'Skipped' -UserName $existing.SamAccountName -Details 'Employee already exists in directory'
    }

    $userName = Get-UniqueUserName -FirstName $Change.FirstName -LastName $Change.LastName -ExistingNames @($Directory | ForEach-Object { $_.SamAccountName })

    # Default groups first, then department groups, without duplicates.
    $groups = [System.Collections.Generic.List[string]]::new()
    foreach ($group in @($Config.DefaultGroups)) {
        if ($group -and -not $groups.Contains($group)) { $groups.Add($group) }
    }
    if ($Change.Department -and $Config.DepartmentGroups) {
        foreach ($group in @($Config.DepartmentGroups.($Change.Department))) {
            if ($group -and -not $groups.Contains($group)) { $groups.Add($group) }
        }
    }

    $user = [pscustomobject]@{
        EmployeeId         = $Change.EmployeeId
        SamAccountName     = $userName
        DisplayName        = '{0} {1}' -f $Change.FirstName, $Change.LastName
        Email              = '{0}@{1}' -f $userName, $Config.Domain
        Department         = $Change.Department
        Title              = $Change.Title
        Manager            = $Change.Manager
        OU                 = 'OU={0},{1}' -f $Change.Department, $Config.UsersOU
        Groups             = @($groups)
        Enabled            = $true
        MustChangePassword = $true
        Created            = Get-Date -Format 'yyyy-MM-dd'
        DisabledOn         = $null
    }

    $groupList = $groups -join ', '
    if ($PSCmdlet.ShouldProcess($userName, "Create account and add to groups: $groupList")) {
        $Directory.Add($user)
        Write-LifecycleLog -Message "Created $userName for $($Change.EmployeeId) ($($Change.Department)); groups: $groupList"
        return ConvertTo-LifecycleResult -Change $Change -Status 'Created' -UserName $userName -Details "Groups: $groupList"
    }

    return ConvertTo-LifecycleResult -Change $Change -Status 'WhatIf' -UserName $userName -Details "Would create account; groups: $groupList"
}
