#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'src' 'UserLifecycle' 'UserLifecycle.psd1'
    Import-Module -Name $modulePath -Force

    $script:Config = [pscustomobject]@{
        Domain           = 'contoso.lab'
        UsersOU          = 'OU=Users,DC=contoso,DC=lab'
        DisabledOU       = 'OU=Disabled Users,DC=contoso,DC=lab'
        DefaultGroups    = @('All Staff')
        DepartmentGroups = [pscustomobject]@{
            IT      = @('IT Admins', 'Jira Users')
            Finance = @('Finance Share')
        }
    }

    function New-TestChange {
        param(
            [string]$EmployeeId = 'E100',
            [string]$FirstName = 'Test',
            [string]$LastName = 'User',
            [string]$Department = 'IT',
            [string]$Action = 'Hire',
            [datetime]$EffectiveDate = '2026-01-01'
        )
        [pscustomobject]@{
            EmployeeId    = $EmployeeId
            FirstName     = $FirstName
            LastName      = $LastName
            Department    = $Department
            Title         = 'Engineer'
            Manager       = ''
            Action        = $Action
            EffectiveDate = $EffectiveDate
        }
    }

    function New-TestDirectoryUser {
        param([string]$EmployeeId = 'E1', [string]$SamAccountName = 'jane.doe', [bool]$Enabled = $true)
        [pscustomobject]@{
            EmployeeId     = $EmployeeId
            SamAccountName = $SamAccountName
            DisplayName    = 'Jane Doe'
            Department     = 'IT'
            OU             = 'OU=IT,OU=Users,DC=contoso,DC=lab'
            Groups         = @('All Staff', 'IT Admins')
            Enabled        = $Enabled
            DisabledOn     = $null
        }
    }
}

Describe 'Get-UniqueUserName' {
    It 'builds first.last in lower case' {
        InModuleScope UserLifecycle {
            Get-UniqueUserName -FirstName 'Yerlan' -LastName 'Omarov' | Should -Be 'yerlan.omarov'
        }
    }

    It 'adds a number when the name is taken' {
        InModuleScope UserLifecycle {
            Get-UniqueUserName -FirstName 'Yerlan' -LastName 'Omarov' -ExistingNames 'yerlan.omarov' |
                Should -Be 'yerlan.omarov2'
            Get-UniqueUserName -FirstName 'Yerlan' -LastName 'Omarov' -ExistingNames 'yerlan.omarov', 'yerlan.omarov2' |
                Should -Be 'yerlan.omarov3'
        }
    }

    It 'removes characters that are not allowed in usernames' {
        InModuleScope UserLifecycle {
            Get-UniqueUserName -FirstName 'Mary-Ann' -LastName "O'Neil" | Should -Be 'maryann.oneil'
        }
    }

    It 'throws for names without Latin letters' {
        InModuleScope UserLifecycle {
            { Get-UniqueUserName -FirstName 'Алия' -LastName 'Касымова' } | Should -Throw '*Latin letters*'
        }
    }
}

Describe 'Import-HRChange' {
    BeforeAll {
        $validCsv = Join-Path $TestDrive 'hr.csv'
        @'
EmployeeId,FirstName,LastName,Department,Title,Action,EffectiveDate,Manager
E1,Anna,Ivanova,IT,Engineer,Hire,2026-01-10,
E2,,,,,Terminate,2026-01-11,
E3,Bad,Action,IT,Engineer,Transfer,2026-01-12,
E4,Bad,Date,IT,Engineer,Hire,12/01/2026,
'@ | Set-Content -Path $validCsv

        $missingColumnCsv = Join-Path $TestDrive 'missing.csv'
        @'
EmployeeId,FirstName,LastName,Department,Title,EffectiveDate
E1,Anna,Ivanova,IT,Engineer,2026-01-10
'@ | Set-Content -Path $missingColumnCsv
    }

    It 'returns only the valid rows' {
        $changes = @(Import-HRChange -Path $validCsv -WarningAction SilentlyContinue)
        $changes.Count | Should -Be 2
        ($changes.EmployeeId -join ',') | Should -Be 'E1,E2'
    }

    It 'converts EffectiveDate to a DateTime' {
        $first = Import-HRChange -Path $validCsv -WarningAction SilentlyContinue | Select-Object -First 1
        $first.EffectiveDate | Should -BeOfType [datetime]
        $first.EffectiveDate.ToString('yyyy-MM-dd') | Should -Be '2026-01-10'
    }

    It 'writes one warning per invalid row' {
        $warnings = @(Import-HRChange -Path $validCsv 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -Be 2
    }

    It 'throws when a required column is missing' {
        { Import-HRChange -Path $missingColumnCsv } | Should -Throw '*missing required column*Action*'
    }
}

Describe 'New-LabUser' {
    It 'creates an account with default and department groups' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $result = New-LabUser -Change (New-TestChange) -Directory $directory -Config $Config

        $result.Status | Should -Be 'Created'
        $directory.Count | Should -Be 1
        $directory[0].SamAccountName | Should -Be 'test.user'
        $directory[0].Email | Should -Be 'test.user@contoso.lab'
        $directory[0].OU | Should -Be 'OU=IT,OU=Users,DC=contoso,DC=lab'
        ($directory[0].Groups -join ',') | Should -Be 'All Staff,IT Admins,Jira Users'
        $directory[0].Enabled | Should -BeTrue
    }

    It 'gives only default groups to a department without a mapping' {
        $directory = [System.Collections.Generic.List[object]]::new()
        New-LabUser -Change (New-TestChange -Department 'Legal') -Directory $directory -Config $Config | Out-Null
        ($directory[0].Groups -join ',') | Should -Be 'All Staff'
    }

    It 'skips an employee who already has an account' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $directory.Add((New-TestDirectoryUser -EmployeeId 'E100'))

        $result = New-LabUser -Change (New-TestChange -EmployeeId 'E100') -Directory $directory -Config $Config -WarningAction SilentlyContinue

        $result.Status | Should -Be 'Skipped'
        $directory.Count | Should -Be 1
    }

    It 'changes nothing with -WhatIf' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $result = New-LabUser -Change (New-TestChange) -Directory $directory -Config $Config -WhatIf

        $result.Status | Should -Be 'WhatIf'
        $directory.Count | Should -Be 0
    }
}

Describe 'Disable-LabUser' {
    It 'disables the account, removes groups and moves it to the Disabled OU' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $directory.Add((New-TestDirectoryUser -EmployeeId 'E1'))

        $result = Disable-LabUser -Change (New-TestChange -EmployeeId 'E1' -Action 'Terminate') -Directory $directory -Config $Config

        $result.Status | Should -Be 'Disabled'
        $directory[0].Enabled | Should -BeFalse
        @($directory[0].Groups).Count | Should -Be 0
        $directory[0].OU | Should -Be 'OU=Disabled Users,DC=contoso,DC=lab'
        $directory[0].DisabledOn | Should -Not -BeNullOrEmpty
    }

    It 'reports NotFound for an unknown employee' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $result = Disable-LabUser -Change (New-TestChange -EmployeeId 'E404' -Action 'Terminate') -Directory $directory -Config $Config -WarningAction SilentlyContinue
        $result.Status | Should -Be 'NotFound'
    }

    It 'skips an account that is already disabled' {
        $directory = [System.Collections.Generic.List[object]]::new()
        $directory.Add((New-TestDirectoryUser -EmployeeId 'E1' -Enabled $false))

        $result = Disable-LabUser -Change (New-TestChange -EmployeeId 'E1' -Action 'Terminate') -Directory $directory -Config $Config
        $result.Status | Should -Be 'Skipped'
    }
}

Describe 'Invoke-UserLifecycle' {
    BeforeEach {
        $directoryPath = Join-Path $TestDrive 'directory.json'
        [ordered]@{ users = @(New-TestDirectoryUser -EmployeeId 'E1') } |
            ConvertTo-Json -Depth 5 | Set-Content -Path $directoryPath

        $hrPath = Join-Path $TestDrive 'hr.csv'
        @'
EmployeeId,FirstName,LastName,Department,Title,Action,EffectiveDate,Manager
E2,Anna,Ivanova,Finance,Analyst,Hire,2026-01-10,
E1,,,,,Terminate,2026-01-11,
E3,Future,Hire,IT,Engineer,Hire,2099-01-01,
E4,Алия,Касымова,IT,Engineer,Hire,2026-01-10,
'@ | Set-Content -Path $hrPath

        $logPath = Join-Path $TestDrive 'logs'
        $runParams = @{
            HRFile        = $hrPath
            DirectoryPath = $directoryPath
            Config        = $Config
            AsOfDate      = [datetime]'2026-06-01'
        }
    }

    It 'onboards, offboards, schedules future changes and isolates failures' {
        $results = Invoke-UserLifecycle @runParams -WarningAction SilentlyContinue

        ($results | Where-Object EmployeeId -EQ 'E2').Status | Should -Be 'Created'
        ($results | Where-Object EmployeeId -EQ 'E1').Status | Should -Be 'Disabled'
        ($results | Where-Object EmployeeId -EQ 'E3').Status | Should -Be 'Scheduled'
        ($results | Where-Object EmployeeId -EQ 'E4').Status | Should -Be 'Failed'
    }

    It 'saves the changes to the directory file' {
        Invoke-UserLifecycle @runParams -WarningAction SilentlyContinue | Out-Null

        $saved = @((Get-Content -Path $directoryPath -Raw | ConvertFrom-Json).users)
        $saved.Count | Should -Be 2
        ($saved | Where-Object EmployeeId -EQ 'E1').Enabled | Should -BeFalse
        ($saved | Where-Object EmployeeId -EQ 'E2').SamAccountName | Should -Be 'anna.ivanova'
    }

    It 'leaves the directory file untouched with -WhatIf' {
        $before = Get-Content -Path $directoryPath -Raw
        $results = Invoke-UserLifecycle @runParams -WhatIf -WarningAction SilentlyContinue

        Get-Content -Path $directoryPath -Raw | Should -Be $before
        ($results | Where-Object EmployeeId -EQ 'E2').Status | Should -Be 'WhatIf'
    }

    It 'writes a log file when LogPath is given' {
        Invoke-UserLifecycle @runParams -LogPath $logPath -WarningAction SilentlyContinue | Out-Null

        $logs = @(Get-ChildItem -Path $logPath -Filter '*.log')
        $logs.Count | Should -Be 1
        Get-Content -Path $logs[0].FullName -Raw | Should -Match 'Run finished'
    }
}

Describe 'Export-LifecycleReport' {
    It 'creates an HTML and a CSV report' {
        $results = @(
            [pscustomobject]@{ Timestamp = '2026-01-01 10:00'; EmployeeId = 'E1'; Name = 'Anna Ivanova'; Action = 'Hire'; Status = 'Created'; UserName = 'anna.ivanova'; Details = 'Groups: All Staff' }
            [pscustomobject]@{ Timestamp = '2026-01-01 10:00'; EmployeeId = 'E2'; Name = 'Jane Doe'; Action = 'Terminate'; Status = 'Disabled'; UserName = 'jane.doe'; Details = 'Removed from: All Staff' }
        )
        $outputPath = Join-Path $TestDrive 'reports'

        $report = $results | Export-LifecycleReport -OutputPath $outputPath

        $report.HtmlPath | Should -Exist
        $report.CsvPath | Should -Exist
        Get-Content -Path $report.HtmlPath -Raw | Should -Match 'anna.ivanova'
        @(Import-Csv -Path $report.CsvPath).Count | Should -Be 2
    }
}
