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

Describe 'ConsoleExporter' {

    Context 'IsShutdown' {
        It 'returns false before Shutdown' {
            InModuleScope $script:projectName {
                $exp = [ConsoleExporter]::new()
                $exp.IsShutdown() | Should -BeFalse
            }
        }

        It 'returns true after Shutdown' {
            InModuleScope $script:projectName {
                $exp = [ConsoleExporter]::new()
                $exp.Shutdown()
                $exp.IsShutdown() | Should -BeTrue
            }
        }
    }

    Context 'Export' {
        It 'does not throw for a valid LogRecord array' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $exp    = [ConsoleExporter]::new()
                $record = [LogRecord]::new('hello', [OtelSeverity]::INFO)
                { $exp.Export(@($record)) } | Should -Not -Throw
            }
        }

        It 'calls Write-Host once per record' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $exp    = [ConsoleExporter]::new()
                $record = [LogRecord]::new('hello', [OtelSeverity]::INFO)
                $exp.Export(@($record))
                Should -Invoke Write-Host -Times 1
            }
        }

        It 'throws InvalidOperationException after Shutdown' {
            InModuleScope $script:projectName {
                $exp    = [ConsoleExporter]::new()
                $record = [LogRecord]::new('hello', [OtelSeverity]::INFO)
                $exp.Shutdown()
                { $exp.Export(@($record)) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }

    Context 'Flush' {
        It 'does not throw' {
            InModuleScope $script:projectName {
                $exp = [ConsoleExporter]::new()
                { $exp.Flush() } | Should -Not -Throw
            }
        }
    }
}
