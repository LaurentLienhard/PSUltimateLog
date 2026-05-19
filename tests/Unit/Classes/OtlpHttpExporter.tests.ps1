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

Describe 'OtlpHttpExporter' {

    Context 'Constructor' {
        It 'trims trailing slash from Endpoint' {
            InModuleScope $script:projectName {
                $exp = [OtlpHttpExporter]::new('http://localhost:4318/')
                $exp.Endpoint | Should -Be 'http://localhost:4318'
            }
        }
    }

    Context 'BuildEnvelope' {
        It 'returns a hashtable with resourceLogs key' {
            InModuleScope $script:projectName {
                $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
                $record   = [LogRecord]::new('test', [OtelSeverity]::INFO)
                $envelope = $exp.BuildEnvelope(@($record))
                $envelope | Should -BeOfType [hashtable]
                $envelope.ContainsKey('resourceLogs') | Should -BeTrue
            }
        }

        It 'resourceLogs[0].scopeLogs[0].scope.name equals PSUltimateLog' {
            InModuleScope $script:projectName {
                $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
                $record   = [LogRecord]::new('test', [OtelSeverity]::INFO)
                $envelope = $exp.BuildEnvelope(@($record))
                $envelope.resourceLogs[0].scopeLogs[0].scope.name | Should -Be 'PSUltimateLog'
            }
        }

        It 'logRecords count matches input array length' {
            InModuleScope $script:projectName {
                $exp     = [OtlpHttpExporter]::new('http://localhost:4318')
                $records = @(
                    [LogRecord]::new('first',  [OtelSeverity]::INFO),
                    [LogRecord]::new('second', [OtelSeverity]::WARN),
                    [LogRecord]::new('third',  [OtelSeverity]::ERROR)
                )
                $envelope = $exp.BuildEnvelope($records)
                $envelope.resourceLogs[0].scopeLogs[0].logRecords.Count | Should -Be 3
            }
        }

        It 'first logRecord has correct severityText' {
            InModuleScope $script:projectName {
                $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
                $record   = [LogRecord]::new('test', [OtelSeverity]::WARN)
                $envelope = $exp.BuildEnvelope(@($record))
                $envelope.resourceLogs[0].scopeLogs[0].logRecords[0].severityText | Should -Be 'WARN'
            }
        }
    }

    Context 'Export' {
        It 'throws InvalidOperationException after Shutdown' {
            InModuleScope $script:projectName {
                $exp    = [OtlpHttpExporter]::new('http://localhost:4318')
                $record = [LogRecord]::new('test', [OtelSeverity]::INFO)
                $exp.Shutdown()
                { $exp.Export(@($record)) } | Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }

        It 'calls Invoke-RestMethod' {
            InModuleScope $script:projectName {
                Mock Invoke-RestMethod {}
                $exp    = [OtlpHttpExporter]::new('http://localhost:4318')
                $record = [LogRecord]::new('test', [OtelSeverity]::INFO)
                $exp.Export(@($record))
                Should -Invoke Invoke-RestMethod -Times 1
            }
        }
    }
}
