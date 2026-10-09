function ConvertTo-LifecycleResult {
    <#
    .SYNOPSIS
        Creates a uniform result object for one processed HR change.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Change,

        [Parameter(Mandatory)]
        [ValidateSet('Created', 'Disabled', 'Skipped', 'Scheduled', 'NotFound', 'Failed', 'WhatIf')]
        [string]$Status,

        [string]$UserName,

        [string]$Name,

        [string]$Details
    )

    if (-not $Name) {
        $Name = ('{0} {1}' -f $Change.FirstName, $Change.LastName).Trim()
    }

    [pscustomobject]@{
        PSTypeName = 'UserLifecycle.Result'
        Timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm'
        EmployeeId = $Change.EmployeeId
        Name       = $Name
        Action     = $Change.Action
        Status     = $Status
        UserName   = $UserName
        Details    = $Details
    }
}
