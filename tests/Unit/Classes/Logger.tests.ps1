BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'Logger' -Tag 'Unit' {

    Context 'Constructor - name only' {

        It 'sets Name correctly' {
            [Logger]::new('MyService').Name | Should -Be 'MyService'
        }

        It 'auto-creates InstrumentationScope with the logger name' {
            $logger = [Logger]::new('MyService')
            $logger.Scope.Name | Should -Be 'MyService'
        }

        It 'Resource is null' {
            [Logger]::new('svc').Resource | Should -BeNull
        }

        It 'TraceContext is null' {
            [Logger]::new('svc').TraceContext | Should -BeNull
        }

        It 'starts with zero exporters' {
            [Logger]::new('svc').GetExporterCount() | Should -Be 0
        }

        It 'throws on null name' {
            { [Logger]::new($null) } | Should -Throw
        }

        It 'throws on empty name' {
            { [Logger]::new('') } | Should -Throw
        }
    }

    Context 'Constructor - name and resource' {

        It 'stores the provided ResourceAttributes' {
            $ra     = [ResourceAttributes]::new('svc')
            $logger = [Logger]::new('svc', $ra)
            $logger.Resource | Should -Be $ra
        }
    }

    Context 'Constructor - name, resource, and scope' {

        It 'stores the provided InstrumentationScope' {
            $ra     = [ResourceAttributes]::new('svc')
            $scope  = [InstrumentationScope]::new('custom-scope', '2.0.0')
            $logger = [Logger]::new('svc', $ra, $scope)
            $logger.Scope.Name    | Should -Be 'custom-scope'
            $logger.Scope.Version | Should -Be '2.0.0'
        }

        It 'falls back to auto-created scope when null is passed' {
            $logger = [Logger]::new('svc', $null, $null)
            $logger.Scope.Name | Should -Be 'svc'
        }
    }

    Context 'AddExporter / RemoveExporter / GetExporterCount' {

        It 'AddExporter increases exporter count' {
            $logger = [Logger]::new('svc')
            $logger.AddExporter([ConsoleExporter]::new())
            $logger.GetExporterCount() | Should -Be 1
        }

        It 'AddExporter accepts multiple exporters' {
            $logger = [Logger]::new('svc')
            $logger.AddExporter([ConsoleExporter]::new())
            $logger.AddExporter([ConsoleExporter]::new())
            $logger.GetExporterCount() | Should -Be 2
        }

        It 'AddExporter throws on null' {
            $logger = [Logger]::new('svc')
            { $logger.AddExporter($null) } | Should -Throw
        }

        It 'RemoveExporter decreases exporter count' {
            $logger = [Logger]::new('svc')
            $exp    = [ConsoleExporter]::new()
            $logger.AddExporter($exp)
            $logger.RemoveExporter($exp)
            $logger.GetExporterCount() | Should -Be 0
        }

        It 'RemoveExporter does not throw for an unregistered exporter' {
            $logger = [Logger]::new('svc')
            { $logger.RemoveExporter([ConsoleExporter]::new()) } | Should -Not -Throw
        }
    }

    Context 'SetTraceContext / ClearTraceContext' {

        It 'SetTraceContext stores the context' {
            $logger = [Logger]::new('svc')
            $ctx    = [TraceContext]::new()
            $logger.SetTraceContext($ctx)
            $logger.TraceContext | Should -Be $ctx
        }

        It 'ClearTraceContext sets TraceContext to null' {
            $logger = [Logger]::new('svc')
            $logger.SetTraceContext([TraceContext]::new())
            $logger.ClearTraceContext()
            $logger.TraceContext | Should -BeNull
        }
    }

    Context 'Log and metrics' {

        It 'increments TotalRecords on each Log call' {
            $logger = [Logger]::new('svc')
            $logger.Log([OtelSeverity]::INFO, 'msg1')
            $logger.Log([OtelSeverity]::INFO, 'msg2')
            $logger.GetMetrics().TotalRecords | Should -Be 2
        }

        It 'increments RecordsBySeverity for the correct level' {
            $logger = [Logger]::new('svc')
            $logger.Log([OtelSeverity]::WARN, 'a warning')
            $logger.GetMetrics().RecordsBySeverity.WARN | Should -Be 1
        }

        It 'tracks each severity level independently' {
            $logger = [Logger]::new('svc')
            $logger.Trace('t'); $logger.Debug('d'); $logger.Info('i')
            $logger.Warn('w');  $logger.Error('e'); $logger.Fatal('f')

            $m = $logger.GetMetrics()
            $m.RecordsBySeverity.TRACE | Should -Be 1
            $m.RecordsBySeverity.DEBUG | Should -Be 1
            $m.RecordsBySeverity.INFO  | Should -Be 1
            $m.RecordsBySeverity.WARN  | Should -Be 1
            $m.RecordsBySeverity.ERROR | Should -Be 1
            $m.RecordsBySeverity.FATAL | Should -Be 1
            $m.TotalRecords            | Should -Be 6
        }

        It 'ExportErrors starts at 0' {
            [Logger]::new('svc').GetMetrics().ExportErrors | Should -Be 0
        }

        It 'increments ExportErrors when an exporter throws' {
            $logger = [Logger]::new('svc')
            $exp    = [ConsoleExporter]::new()
            $exp.Shutdown()                      # will throw on Export
            $logger.AddExporter($exp)
            $logger.Info('this will fail')
            $logger.GetMetrics().ExportErrors | Should -Be 1
        }

        It 'still counts TotalRecords even when export fails' {
            $logger = [Logger]::new('svc')
            $exp    = [ConsoleExporter]::new()
            $exp.Shutdown()
            $logger.AddExporter($exp)
            $logger.Info('fail')
            $logger.GetMetrics().TotalRecords | Should -Be 1
        }

        It 'GetMetrics returns a copy — mutations do not affect internal state' {
            $logger  = [Logger]::new('svc')
            $metrics = $logger.GetMetrics()
            $metrics.TotalRecords = 999
            $logger.GetMetrics().TotalRecords | Should -Be 0
        }
    }

    Context 'Convenience methods' {

        It 'Trace logs at TRACE severity' {
            $logger = [Logger]::new('svc')
            $logger.Trace('t')
            $logger.GetMetrics().RecordsBySeverity.TRACE | Should -Be 1
        }

        It 'Debug logs at DEBUG severity' {
            $logger = [Logger]::new('svc')
            $logger.Debug('d')
            $logger.GetMetrics().RecordsBySeverity.DEBUG | Should -Be 1
        }

        It 'Info logs at INFO severity' {
            $logger = [Logger]::new('svc')
            $logger.Info('i')
            $logger.GetMetrics().RecordsBySeverity.INFO | Should -Be 1
        }

        It 'Warn logs at WARN severity' {
            $logger = [Logger]::new('svc')
            $logger.Warn('w')
            $logger.GetMetrics().RecordsBySeverity.WARN | Should -Be 1
        }

        It 'Error logs at ERROR severity' {
            $logger = [Logger]::new('svc')
            $logger.Error('e')
            $logger.GetMetrics().RecordsBySeverity.ERROR | Should -Be 1
        }

        It 'Fatal logs at FATAL severity' {
            $logger = [Logger]::new('svc')
            $logger.Fatal('f')
            $logger.GetMetrics().RecordsBySeverity.FATAL | Should -Be 1
        }
    }

    Context 'Log with TraceContext' {

        It 'propagates TraceId to exported records' {
            $path   = Join-Path $TestDrive 'trace.jsonl'
            $logger = [Logger]::new('svc')
            $logger.AddExporter([FileExporter]::new($path))
            $ctx = [TraceContext]::new()
            $logger.SetTraceContext($ctx)
            $logger.Info('traced message')

            $record = Get-Content -Path $path -Raw | ConvertFrom-Json
            $record.traceId | Should -Be $ctx.TraceId
        }

        It 'records have empty traceId when no context is set' {
            $path   = Join-Path $TestDrive 'notrace.jsonl'
            $logger = [Logger]::new('svc')
            $logger.AddExporter([FileExporter]::new($path))
            $logger.Info('no trace')

            $record = Get-Content -Path $path -Raw | ConvertFrom-Json
            $record.traceId | Should -Be ''
        }
    }

    Context 'Log with FileExporter' {

        It 'writes one line per log call' {
            $path   = Join-Path $TestDrive 'lines.jsonl'
            $logger = [Logger]::new('svc')
            $logger.AddExporter([FileExporter]::new($path))

            $logger.Info('first')
            $logger.Warn('second')
            $logger.Error('third')

            (Get-Content -Path $path).Count | Should -Be 3
        }

        It 'written JSON contains the correct body' {
            $path   = Join-Path $TestDrive 'body.jsonl'
            $logger = [Logger]::new('svc')
            $logger.AddExporter([FileExporter]::new($path))
            $logger.Info('hello logger')

            (Get-Content -Path $path -Raw | ConvertFrom-Json).body.stringValue | Should -Be 'hello logger'
        }
    }

    Context 'Flush and Shutdown' {

        It 'Flush does not throw with no exporters' {
            { [Logger]::new('svc').Flush() } | Should -Not -Throw
        }

        It 'Shutdown does not throw with no exporters' {
            { [Logger]::new('svc').Shutdown() } | Should -Not -Throw
        }

        It 'Shutdown marks registered FileExporter as shut down' {
            $logger = [Logger]::new('svc')
            $exp    = [FileExporter]::new(Join-Path $TestDrive 'sd.jsonl')
            $logger.AddExporter($exp)
            $logger.Shutdown()
            $exp.IsShutdown | Should -BeTrue
        }

        It 'Flush does not throw when an exporter errors' {
            $logger = [Logger]::new('svc')
            $exp    = [LogExporter]::new()          # base class — Flush throws
            $logger.AddExporter($exp)
            { $logger.Flush() } | Should -Not -Throw
        }
    }
}
