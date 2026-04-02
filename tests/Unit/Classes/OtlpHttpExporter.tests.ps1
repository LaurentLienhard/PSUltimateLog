using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'OtlpHttpExporter' -Tag 'Unit' {

    Context 'Constructor' {

        It 'stores the Endpoint property' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            $exp.Endpoint | Should -Be 'http://localhost:4318'
        }

        It 'trims trailing slash from endpoint' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318/')
            $exp.Endpoint | Should -Be 'http://localhost:4318'
        }

        It 'IsShutdown is false after construction' {
            [OtlpHttpExporter]::new('http://localhost:4318').IsShutdown | Should -BeFalse
        }

        It 'inherits from LogExporter' {
            [OtlpHttpExporter]::new('http://localhost:4318') -is [LogExporter] | Should -BeTrue
        }

        It 'throws on null endpoint' {
            { [OtlpHttpExporter]::new($null) } | Should -Throw
        }

        It 'throws on empty endpoint' {
            { [OtlpHttpExporter]::new('') } | Should -Throw
        }

        It 'throws on whitespace endpoint' {
            { [OtlpHttpExporter]::new('   ') } | Should -Throw
        }
    }

    Context 'Export' {

        It 'does nothing for an empty records array' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            { $exp.Export(@()) } | Should -Not -Throw
        }

        It 'does nothing for a null records array' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            { $exp.Export($null) } | Should -Not -Throw
        }

        It 'calls Invoke-RestMethod with the correct URI' {
            InModuleScope $ProjectName {
                Mock Invoke-RestMethod {}

                $exp    = [OtlpHttpExporter]::new('http://localhost:4318')
                $record = [LogRecord]::new('msg', [OtelSeverity]::INFO)
                $exp.Export(@($record))

                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Uri -eq 'http://localhost:4318/v1/logs'
                }
            }
        }

        It 'calls Invoke-RestMethod with POST method' {
            InModuleScope $ProjectName {
                Mock Invoke-RestMethod {}

                $exp    = [OtlpHttpExporter]::new('http://localhost:4318')
                $record = [LogRecord]::new('msg', [OtelSeverity]::INFO)
                $exp.Export(@($record))

                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
                    $Method -eq 'Post'
                }
            }
        }

        It 'throws after Shutdown' {
            $exp    = [OtlpHttpExporter]::new('http://localhost:4318')
            $record = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $exp.Shutdown()
            { $exp.Export(@($record)) } | Should -Throw
        }
    }

    Context 'Flush' {

        It 'does not throw' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            { $exp.Flush() } | Should -Not -Throw
        }
    }

    Context 'Shutdown' {

        It 'sets IsShutdown to true' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            $exp.Shutdown()
            $exp.IsShutdown | Should -BeTrue
        }

        It 'does not throw on repeated calls' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            $exp.Shutdown()
            { $exp.Shutdown() } | Should -Not -Throw
        }
    }

    Context 'BuildEnvelope' {

        It 'returns a hashtable with resourceLogs key' {
            $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
            $record   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $envelope = $exp.BuildEnvelope(@($record))
            $envelope.Keys | Should -Contain 'resourceLogs'
        }

        It 'resourceLogs contains one entry' {
            $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
            $record   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $envelope = $exp.BuildEnvelope(@($record))
            $envelope.resourceLogs.Count | Should -Be 1
        }

        It 'scopeLogs contains one entry' {
            $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
            $record   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $envelope = $exp.BuildEnvelope(@($record))
            $envelope.resourceLogs[0].scopeLogs.Count | Should -Be 1
        }

        It 'logRecords count matches the input' {
            $exp = [OtlpHttpExporter]::new('http://localhost:4318')
            $records = @(
                [LogRecord]::new('a', [OtelSeverity]::INFO)
                [LogRecord]::new('b', [OtelSeverity]::WARN)
            )
            $envelope = $exp.BuildEnvelope($records)
            $envelope.resourceLogs[0].scopeLogs[0].logRecords.Count | Should -Be 2
        }

        It 'scope name is PSUltimateLog' {
            $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
            $record   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $envelope = $exp.BuildEnvelope(@($record))
            $envelope.resourceLogs[0].scopeLogs[0].scope.name | Should -Be 'PSUltimateLog'
        }

        It 'logRecords contain the correct severityText' {
            $exp      = [OtlpHttpExporter]::new('http://localhost:4318')
            $record   = [LogRecord]::new('msg', [OtelSeverity]::ERROR)
            $envelope = $exp.BuildEnvelope(@($record))
            $envelope.resourceLogs[0].scopeLogs[0].logRecords[0].severityText | Should -Be 'ERROR'
        }
    }
}
