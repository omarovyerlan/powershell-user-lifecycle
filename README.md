# PowerShell User Lifecycle Automation

![CI](https://github.com/omarovyerlan/powershell-user-lifecycle/actions/workflows/ci.yml/badge.svg)

Automates **employee onboarding and offboarding** from an HR feed: creates accounts with the right groups for new hires, disables leavers and removes their access, and produces an audit log plus HTML/CSV reports.

It is built as a proper PowerShell module with tests and CI. A JSON file stands in for Active Directory, so it runs anywhere PowerShell 7 runs (macOS, Linux, Windows). The same logic maps directly onto the `ActiveDirectory` or Microsoft Graph cmdlets in production.



## What it does

| HR event | Automation |
|---|---|
| **Hire** | Generates a unique username (`first.last`, `first.last2`, …) and email, places the account in the department OU, assigns default and department groups, and flags it as "must change password" |
| **Terminate** | Disables the account, removes **all** group memberships, moves it to the Disabled OU and records the date |
| **Future date** | Reported as `Scheduled` and left for a later run |
| **Bad data** | Invalid rows are skipped with a warning; one failed record never stops the run |

Every run writes a timestamped **log file** and an **HTML report** (for people) plus a **CSV report** (for audit and Excel).

## Engineering practices

- **Module structure:** public and private functions, a manifest (`.psd1`) and explicit exports
- **Configuration as data:** domain, OUs and group mappings live in `config/settings.json`, not in code
- **Safe changes:** full `-WhatIf` support. A dry run shows exactly what would change and writes a report, without touching the directory
- **Validation and error handling:** the HR feed is validated row by row, and errors are isolated per record
- **Logging:** structured, timestamped entries (`[INFO]`, `[WARNING]`, `[ERROR]`) per run
- **Comment-based help:** every public function works with `Get-Help`
- **Tests:** Pester 5 unit and integration tests, using `TestDrive` for isolated file I/O
- **CI:** GitHub Actions runs PSScriptAnalyzer and the Pester tests on **Ubuntu, Windows and macOS** on every push, then does a demo run and uploads the reports

## Quick start

Requirements: [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).

```powershell
# 1. Dry run: see what would happen; nothing is changed
./scripts/Start-UserLifecycle.ps1 -WhatIf

# 2. Live run against the lab directory
./scripts/Start-UserLifecycle.ps1

# 3. Start over from the original sample directory, with detailed output
./scripts/Start-UserLifecycle.ps1 -Reset -Verbose
```

Example output with the sample data:

```
EmployeeId Name               Action    Status    UserName
---------- ----               ------    ------    --------
E2001      Arman Zhaksybekov  Hire      Created   arman.zhaksybekov
E2002      Maria Lopez        Hire      Created   maria.lopez
E2003      Aigerim Seitkali   Hire      Created   aigerim.seitkali2
E1002      Timur Sadykov      Terminate Disabled  timur.sadykov
E9999                         Terminate NotFound
E2004      Nurlan Abenov      Hire      Scheduled
E2005      Алия Касымова      Hire      Failed
```

The sample feed deliberately includes edge cases: a duplicate name (`aigerim.seitkali2`), an unknown employee, a future-dated hire, a name without Latin letters, and a row with an invalid action (`Transfer`), which is skipped at validation.

Reports and logs are saved in `output/`.

## Use the module directly

```powershell
Import-Module ./src/UserLifecycle/UserLifecycle.psd1
Get-Help Invoke-UserLifecycle -Full

$config = Get-Content ./config/settings.json -Raw | ConvertFrom-Json
Invoke-UserLifecycle -HRFile ./data/hr-changes.csv -DirectoryPath ./output/directory.json -Config $config -WhatIf |
    Export-LifecycleReport -OutputPath ./output/reports
```

## Run the tests

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Invoke-Pester ./tests -Output Detailed
```

## Project structure

```
powershell-user-lifecycle/
├── src/UserLifecycle/
│   ├── UserLifecycle.psd1        # module manifest
│   ├── UserLifecycle.psm1        # loads functions, exports the public ones
│   ├── Public/                   # Import-HRChange, New-LabUser, Disable-LabUser,
│   │                             # Invoke-UserLifecycle, Export-LifecycleReport
│   └── Private/                  # logging, directory storage, username generation
├── scripts/Start-UserLifecycle.ps1   # entry point
├── config/settings.json          # domain, OUs, group mappings
├── data/
│   ├── hr-changes.csv            # sample HR feed
│   └── directory.seed.json       # sample "Active Directory"
├── tests/UserLifecycle.Tests.ps1 # Pester tests
├── .github/workflows/ci.yml      # lint + tests on 3 operating systems
└── docs/                         # screenshots
```

## From lab to production

| Lab (this repo) | Production equivalent |
|---|---|
| `data/directory.seed.json` | Active Directory / Microsoft Entra ID |
| `New-LabUser` | `New-ADUser` + `Add-ADGroupMember`, or Microsoft Graph `New-MgUser` |
| `Disable-LabUser` | `Disable-ADAccount`, `Remove-ADGroupMember`, `Move-ADObject` |
| `data/hr-changes.csv` | Export or API feed from the HR system |
| Manual run | Scheduled task or CI/CD job, with reports emailed or posted to Slack |

## Author

**Yerlan Omarov**, IT Infrastructure & Systems Engineer · [LinkedIn](https://www.linkedin.com/in/yerlanomarov)
