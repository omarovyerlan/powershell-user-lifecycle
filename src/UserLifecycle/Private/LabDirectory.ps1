function Read-LabDirectory {
    <#
    .SYNOPSIS
        Loads the lab directory (a JSON stand-in for Active Directory) into a mutable list.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Directory file not found: $Path"
    }

    $data = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($user in @($data.users)) {
        if ($null -ne $user) { $list.Add($user) }
    }

    # The leading comma stops PowerShell from unrolling the list into single objects.
    return , $list
}

function Save-LabDirectory {
    <#
    .SYNOPSIS
        Writes the lab directory back to its JSON file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Users
    )

    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force -WhatIf:$false | Out-Null
    }

    [ordered]@{ users = @($Users) } |
        ConvertTo-Json -Depth 5 |
        Set-Content -Path $Path -Encoding utf8 -WhatIf:$false
}
