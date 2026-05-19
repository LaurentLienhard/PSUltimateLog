BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName) {
        $ProjectName = (Get-ChildItem -Path "$projectPath\*\*.psd1" |
            Where-Object { $_.FullName -notmatch '(output|RequiredModules)' } |
            Select-Object -First 1).BaseName
    }
    $script:projectName = $ProjectName
    if (-not (Get-Module -Name $script:projectName -ErrorAction SilentlyContinue)) {
        $manifest = Get-ChildItem -Path "$projectPath" -Filter "$script:projectName.psd1" -Recurse |
            Where-Object { $_.FullName -notmatch '(output|RequiredModules)' } |
            Select-Object -First 1
        Import-Module -Name $manifest.FullName -Force -ErrorAction Stop
    }
}

Describe 'LogExporter' {

    Context 'IsShutdown' {
        It 'returns false on a new instance' {
            InModuleScope $script:projectName {
                $exp = [LogExporter]::new()
                $exp.IsShutdown() | Should -BeFalse
            }
        }
    }

    Context 'Shutdown' {
        It 'causes IsShutdown to return true' {
            InModuleScope $script:projectName {
                $exp = [LogExporter]::new()
                $exp.Shutdown()
                $exp.IsShutdown() | Should -BeTrue
            }
        }
    }

    Context 'Export' {
        It 'throws NotImplementedException' {
            InModuleScope $script:projectName {
                $exp    = [LogExporter]::new()
                $record = [LogRecord]::new('test', [OtelSeverity]::INFO)
                { $exp.Export(@($record)) } | Should -Throw -ExceptionType ([System.NotImplementedException])
            }
        }
    }

    Context 'Flush' {
        It 'does not throw' {
            InModuleScope $script:projectName {
                $exp = [LogExporter]::new()
                { $exp.Flush() } | Should -Not -Throw
            }
        }
    }
}
