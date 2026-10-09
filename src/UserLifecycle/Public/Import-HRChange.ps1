function Import-HRChange {
    <#
    .SYNOPSIS
        Reads and validates an HR change feed (CSV).
    .DESCRIPTION
        Each row describes a Hire or Terminate event. Rows with missing or invalid data are
        skipped with a warning, so one bad row never stops the whole run.
        A missing required column is treated as a fatal error.
    .PARAMETER Path
        Path to the CSV file. Required columns:
        EmployeeId, FirstName, LastName, Department, Title, Action, EffectiveDate (yyyy-MM-dd).
        Optional column: Manager.
    .EXAMPLE
        Import-HRChange -Path ./data/hr-changes.csv
    .OUTPUTS
        UserLifecycle.HRChange objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$Path
    )

    $requiredColumns = @('EmployeeId', 'FirstName', 'LastName', 'Department', 'Title', 'Action', 'EffectiveDate')

    $rows = @(Import-Csv -Path $Path)
    if ($rows.Count -eq 0) {
        Write-LifecycleLog -Message "No records found in $Path" -Level Warning
        return
    }

    $columns = $rows[0].PSObject.Properties.Name
    $missing = @($requiredColumns | Where-Object { $_ -notin $columns })
    if ($missing.Count -gt 0) {
        throw "HR file '$Path' is missing required column(s): $($missing -join ', ')"
    }

    $lineNumber = 1   # header is line 1
    foreach ($row in $rows) {
        $lineNumber++
        $problems = [System.Collections.Generic.List[string]]::new()

        if ([string]::IsNullOrWhiteSpace($row.EmployeeId)) {
            $problems.Add('EmployeeId is empty')
        }

        if ($row.Action -notin 'Hire', 'Terminate') {
            $problems.Add("unknown Action '$($row.Action)' (expected Hire or Terminate)")
        }

        $effectiveDate = [datetime]::MinValue
        $isValidDate = [datetime]::TryParseExact(
            "$($row.EffectiveDate)".Trim(),
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$effectiveDate
        )
        if (-not $isValidDate) {
            $problems.Add("invalid EffectiveDate '$($row.EffectiveDate)' (expected yyyy-MM-dd)")
        }

        if ($row.Action -eq 'Hire' -and
            ([string]::IsNullOrWhiteSpace($row.FirstName) -or [string]::IsNullOrWhiteSpace($row.LastName))) {
            $problems.Add('Hire requires FirstName and LastName')
        }

        if ($problems.Count -gt 0) {
            Write-LifecycleLog -Message "Skipping line ${lineNumber}: $($problems -join '; ')" -Level Warning
            continue
        }

        [pscustomobject]@{
            PSTypeName    = 'UserLifecycle.HRChange'
            EmployeeId    = $row.EmployeeId.Trim()
            FirstName     = "$($row.FirstName)".Trim()
            LastName      = "$($row.LastName)".Trim()
            Department    = "$($row.Department)".Trim()
            Title         = "$($row.Title)".Trim()
            Manager       = "$($row.Manager)".Trim()
            Action        = if ($row.Action -eq 'Hire') { 'Hire' } else { 'Terminate' }
            EffectiveDate = $effectiveDate
        }
    }
}
