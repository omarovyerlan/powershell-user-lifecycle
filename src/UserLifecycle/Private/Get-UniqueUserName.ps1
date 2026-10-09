function Get-UniqueUserName {
    <#
    .SYNOPSIS
        Builds a unique "first.last" username, adding a number if the name is already taken.
    .EXAMPLE
        Get-UniqueUserName -FirstName 'Yerlan' -LastName 'Omarov' -ExistingNames 'yerlan.omarov'
        # -> yerlan.omarov2
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [string]$LastName,

        [string[]]$ExistingNames = @()
    )

    # Keep only a-z so the result is safe for usernames and email addresses.
    $first = $FirstName.ToLowerInvariant() -replace '[^a-z]', ''
    $last  = $LastName.ToLowerInvariant()  -replace '[^a-z]', ''

    if (-not $first -or -not $last) {
        throw "Cannot build a username from '$FirstName $LastName': name must contain Latin letters."
    }

    $taken = @($ExistingNames | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })

    $base = '{0}.{1}' -f $first, $last
    $candidate = $base
    $suffix = 2
    while ($taken -contains $candidate) {
        $candidate = '{0}{1}' -f $base, $suffix
        $suffix++
    }

    return $candidate
}
