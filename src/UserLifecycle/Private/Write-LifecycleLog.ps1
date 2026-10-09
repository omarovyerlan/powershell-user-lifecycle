function Write-LifecycleLog {
    <#
    .SYNOPSIS
        Writes a timestamped entry to the run log and to the matching PowerShell stream.
    .DESCRIPTION
        Info messages go to the Verbose stream, warnings and errors to the Warning stream.
        If a log file is active for the current run, every entry is also appended to it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
    $line = '{0} [{1}] {2}' -f $timestamp, $Level.ToUpperInvariant(), $Message

    if ($script:LogFile -and (Test-Path -Path (Split-Path -Path $script:LogFile -Parent))) {
        # -WhatIf:$false so the log is still written during a dry run.
        Add-Content -Path $script:LogFile -Value $line -Encoding utf8 -WhatIf:$false
    }

    switch ($Level) {
        'Info'    { Write-Verbose -Message $Message }
        'Warning' { Write-Warning -Message $Message }
        'Error'   { Write-Warning -Message "ERROR: $Message" }
    }
}
