function Export-LifecycleReport {
    <#
    .SYNOPSIS
        Saves lifecycle results as an HTML report (for people) and a CSV file (for audit/Excel).
    .PARAMETER Result
        Result objects from Invoke-UserLifecycle. Accepts pipeline input.
    .PARAMETER OutputPath
        Folder for the report files. Created if it does not exist.
    .PARAMETER Title
        Report heading.
    .EXAMPLE
        Invoke-UserLifecycle @params | Export-LifecycleReport -OutputPath ./output/reports
    .OUTPUTS
        Object with HtmlPath and CsvPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [object[]]$Result,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$Title = 'User Lifecycle Report'
    )

    begin {
        $all = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $Result) {
            if ($null -ne $item) { $all.Add($item) }
        }
    }

    end {
        if (-not (Test-Path -Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force -WhatIf:$false | Out-Null
        }

        $stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
        $csvPath  = Join-Path $OutputPath "lifecycle-report-$stamp.csv"
        $htmlPath = Join-Path $OutputPath "lifecycle-report-$stamp.html"
        $columns  = 'Timestamp', 'EmployeeId', 'Name', 'Action', 'Status', 'UserName', 'Details'

        $all | Select-Object -Property $columns |
            Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8 -WhatIf:$false

        $pills = $all | Group-Object -Property Status | Sort-Object -Property Name | ForEach-Object {
            '<span class="pill {0}">{0}: {1}</span>' -f $_.Name, $_.Count
        }

        $table = ($all | Select-Object -Property $columns | ConvertTo-Html -Fragment) -join "`n"
        $table = $table -replace '<td>(Created|Disabled|Skipped|Scheduled|NotFound|Failed|WhatIf)</td>', '<td><span class="pill $1">$1</span></td>'

        $css = @'
body { font-family: -apple-system, "Segoe UI", Roboto, sans-serif; margin: 32px; color: #1f2937; background: #f8fafc; }
h1 { margin-bottom: 4px; }
.meta { color: #6b7280; margin-top: 0; }
.summary { margin: 16px 0 24px; }
table { border-collapse: collapse; width: 100%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
th { background: #0b1930; color: #fff; text-align: left; padding: 10px; font-weight: 600; }
td { padding: 9px 10px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
.pill { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; margin-right: 6px; }
.Created { background: #dcfce7; color: #166534; }
.Disabled { background: #fee2e2; color: #991b1b; }
.Scheduled { background: #dbeafe; color: #1e40af; }
.Skipped, .WhatIf { background: #f3f4f6; color: #374151; }
.NotFound, .Failed { background: #fef3c7; color: #92400e; }
'@

        $body = @(
            "<h1>$Title</h1>"
            "<p class=""meta"">Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') &middot; $($all.Count) record(s)</p>"
            "<div class=""summary"">$($pills -join ' ')</div>"
            $table
        ) -join "`n"

        ConvertTo-Html -Title $Title -Head "<style>$css</style>" -Body $body |
            Set-Content -Path $htmlPath -Encoding utf8 -WhatIf:$false

        Write-LifecycleLog -Message "Report saved: $htmlPath"

        [pscustomobject]@{
            HtmlPath = $htmlPath
            CsvPath  = $csvPath
        }
    }
}
