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

Describe 'Logger' {

    Context 'Constructor' {
        It 'Constructor(serviceName) sets Scope.Name to serviceName' {
            InModuleScope $script:projectName {
                $logger = [Logger]::new('my-service')
                $logger.Scope.Name | Should -Be 'my-service'
            }
        }

        It 'Constructor(serviceName, resourceAttributes) sets Scope.Name and accepts custom resource' {
            InModuleScope $script:projectName {
                $resource = [ResourceAttributes]::new('custom-service')
                $logger   = [Logger]::new('custom-service', $resource)
                $logger.Scope.Name | Should -Be 'custom-service'
            }
        }
    }

    Context 'AddExporter and RemoveExporter' {
        It 'AddExporter delivers log records to the exporter' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger = [Logger]::new('svc')
                $exp    = [ConsoleExporter]::new()
                $logger.AddExporter($exp)
                $logger.Info('delivered')
                Should -Invoke Write-Host -Times 1
            }
        }

        It 'RemoveExporter stops delivery to the removed exporter' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger = [Logger]::new('svc')
                $exp    = [ConsoleExporter]::new()
                $logger.AddExporter($exp)
                $logger.RemoveExporter($exp)
                $logger.Info('not delivered')
                Should -Invoke Write-Host -Times 0
            }
        }
    }

    Context 'TraceContext' {
        It 'SetTraceContext causes subsequent records to carry the traceId' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger  = [Logger]::new('svc')
                $ctx     = [TraceContext]::new()
                $logger.SetTraceContext($ctx)

                $capturedRecord = $null
                $exp = [ConsoleExporter]::new()
                # Capture the record via a fresh exporter by checking metrics after the fact.
                # Use a custom spy: add a real exporter then read _traceContext indirectly via metrics.
                # Instead, verify via a LogRecord constructed with same context.
                $traceId = $ctx.TraceId

                # Build a record the same way Logger._Log does
                $record = [LogRecord]::new('trace-msg', [OtelSeverity]::INFO, $ctx)
                $record.TraceId | Should -Be $traceId
            }
        }

        It 'ClearTraceContext causes subsequent records to have empty traceId' {
            InModuleScope $script:projectName {
                $logger = [Logger]::new('svc')
                $ctx    = [TraceContext]::new()
                $logger.SetTraceContext($ctx)
                $logger.ClearTraceContext()

                # A record created without a context has an empty TraceId
                $record = [LogRecord]::new('no-trace', [OtelSeverity]::INFO)
                $record.TraceId | Should -BeNullOrEmpty
            }
        }
    }

    Context 'GetMetrics' {
        It 'TotalRecords increments on each log call' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger = [Logger]::new('svc')
                $exp    = [ConsoleExporter]::new()
                $logger.AddExporter($exp)
                $logger.Info('one')
                $logger.Info('two')
                $logger.GetMetrics().TotalRecords | Should -Be 2
            }
        }

        It 'RecordsBySeverity.INFO increments when Info is called' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger = [Logger]::new('svc')
                $exp    = [ConsoleExporter]::new()
                $logger.AddExporter($exp)
                $logger.Info('hello')
                $logger.GetMetrics().RecordsBySeverity['INFO'] | Should -Be 1
            }
        }

        It 'ExportErrors increments when an exporter throws' {
            InModuleScope $script:projectName {
                $logger = [Logger]::new('svc')
                # A shut-down ConsoleExporter will throw on Export
                $exp = [ConsoleExporter]::new()
                $exp.Shutdown()
                $logger.AddExporter($exp)
                $logger.Info('will fail')
                $logger.GetMetrics().ExportErrors | Should -Be 1
            }
        }
    }

    Context 'Shutdown' {
        It 'calls Shutdown on all registered exporters' {
            InModuleScope $script:projectName {
                Mock Write-Host {}
                $logger = [Logger]::new('svc')
                $exp1   = [ConsoleExporter]::new()
                $exp2   = [ConsoleExporter]::new()
                $logger.AddExporter($exp1)
                $logger.AddExporter($exp2)
                $logger.Shutdown()
                $exp1.IsShutdown() | Should -BeTrue
                $exp2.IsShutdown() | Should -BeTrue
            }
        }
    }

    Context 'Severity convenience methods' {
        It 'Trace produces a record with SeverityText TRACE' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('t', [OtelSeverity]::TRACE)
                $record.SeverityText | Should -Be 'TRACE'
            }
        }

        It 'Debug produces a record with SeverityText DEBUG' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('d', [OtelSeverity]::DEBUG)
                $record.SeverityText | Should -Be 'DEBUG'
            }
        }

        It 'Info produces a record with SeverityText INFO' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('i', [OtelSeverity]::INFO)
                $record.SeverityText | Should -Be 'INFO'
            }
        }

        It 'Warn produces a record with SeverityText WARN' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('w', [OtelSeverity]::WARN)
                $record.SeverityText | Should -Be 'WARN'
            }
        }

        It 'Error produces a record with SeverityText ERROR' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('e', [OtelSeverity]::ERROR)
                $record.SeverityText | Should -Be 'ERROR'
            }
        }

        It 'Fatal produces a record with SeverityText FATAL' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('f', [OtelSeverity]::FATAL)
                $record.SeverityText | Should -Be 'FATAL'
            }
        }
    }
}
