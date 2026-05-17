<#
.SYNOPSIS
    Pester tests for Implementation Plan Task 3 Sub-task J (Task 3 closure verification).

.DESCRIPTION
    Validates Task 3 smoke behavior, checklist state in the task slice plan and parent
    implementation plan, and that Task 4+ scope was not started. Imports the root
    script module only (no Graph manifest dependency for CSV smoke).
#>

BeforeAll {
    $script:RepoRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ErrorAction Stop).Path
    $script:TaskPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/tasks/task-3/PLAN-Task-3-Provisioning-Csv.md'
    $script:ImplementationPlanPath = Join-Path -Path $script:RepoRoot -ChildPath 'docs/IMPLEMENTATION-PLAN.md'
    $script:Psm1Path = Join-Path -Path $script:RepoRoot -ChildPath 'src/Modules/BulkIdentityManagement/BulkIdentityManagement.psm1'

    Import-Module -Name $script:Psm1Path -Force -ErrorAction Stop

    function script:Write-ProvisioningCsvUtf8NoBom {
        param(
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter(Mandatory)]
            [string] $Content
        )

        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM -NoNewline:$false
    }
}

AfterAll {
    Remove-Module -Name BulkIdentityManagement -Force -ErrorAction SilentlyContinue
}

Describe 'Task 3 Sub-task J - Import-ProvisioningCsv closure smoke' {

    It 'imports a minimal good CSV and returns expected provisioning row properties' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'closure-good.csv'
        $content = @(
            'FirstName,LastName,Department'
            'Ada,Lovelace,Engineering'
        ) -join "`n"
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content $content

        $rows = @(Import-ProvisioningCsv -Path $csvPath)

        $rows.Count | Should -Be 1
        $rows[0].FirstName | Should -Be 'Ada'
        $rows[0].LastName | Should -Be 'Lovelace'
        $rows[0].Department | Should -Be 'Engineering'
        $rows[0].SourceLineNumber | Should -Be 2
    }

    It 'throws a human-readable header error for a bad CSV without emitting pipeline objects' {
        $csvPath = Join-Path -Path $TestDrive -ChildPath 'closure-bad.csv'
        Write-ProvisioningCsvUtf8NoBom -Path $csvPath -Content 'FirstName,Department'

        $emitted = [System.Collections.Generic.List[object]]::new()
        $thrown = $null
        try {
            Import-ProvisioningCsv -Path $csvPath | ForEach-Object { $emitted.Add($_) | Out-Null }
        }
        catch {
            $thrown = $_
        }

        $thrown.Exception | Should -BeOfType ([System.InvalidOperationException])
        $thrown.Exception.Message | Should -Match 'LastName'
        $thrown.Exception.Message | Should -Match 'header'
        $emitted.Count | Should -Be 0
    }
}

Describe 'Task 3 Sub-task J - closure checklist verification' {

    It 'marks Sub-task J acceptance and verification complete in the Task 3 slice plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] Parent plan Task 3 acceptance criteria satisfied \(headers before rows, UTF-8/BOM, clear errors, tests pass\)\.'
        $taskPlan | Should -Match '(?m)^- \[x\] No Task 4\+ code or tests introduced\.'
        $taskPlan | Should -Match '(?m)^- \[x\] `Invoke-Pester` Task 3 tests green\.'
        $taskPlan | Should -Match '(?m)^- \[x\] Manual: good \+ bad CSV per implementation plan\.'
        $taskPlan | Should -Match '(?m)^- \[x\] Quick review: CSV error messages human-readable\.'
    }

    It 'marks Task 3 completion checkpoints complete in the Task 3 slice plan' {
        $taskPlan = Get-Content -LiteralPath $script:TaskPlanPath -Raw
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`Invoke-Pester`\*\* passes for \*\*H\*\* \+ \*\*I\*\* without live tenant\.'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*IMPLEMENTATION-PLAN\*\* Task 3 boxes updated\.'
        $taskPlan | Should -Match '(?m)^- \[x\] Ready for \*\*Task 4\*\* \(depends on stable \*\*provisioning row\*\* shape\)'
        $taskPlan | Should -Match '(?m)^- \[x\] \*\*`Import-ProvisioningCsv`\*\* callable from imported module\.'
    }

    It 'marks only Task 3 acceptance and verification bullets complete in the parent implementation plan' {
        $implementationPlan = Get-Content -LiteralPath $script:ImplementationPlanPath -Raw
        $implementationPlan | Should -Match '(?m)^- \[x\] Required headers validated before row iteration\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] UTF-8 with and without BOM reads correctly\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Malformed files produce clear, actionable errors \(no partial silent apply\)\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Tests pass: `Invoke-Pester` \(or `pwsh -c "Invoke-Pester ''tests/\.\.\.''"`\) scoped to CSV contract tests\.'
        $implementationPlan | Should -Match '(?m)^- \[x\] Manual: Run validator against a tiny good CSV and a bad CSV\.'
    }

}
