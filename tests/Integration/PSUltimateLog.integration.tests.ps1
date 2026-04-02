using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\.." | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

# =============================================================================
# Example 1 — Minimal logger: write a few messages to a file
# =============================================================================

Describe 'Example 1 — Minimal logger with FileExporter' -Tag 'Integration' {

    It 'logs messages at different severity levels and writes them as JSONL' {
        $logFile = Join-Path $TestDrive 'app.jsonl'

        # Create a logger and attach a file exporter
        $logger = [Logger]::new('my-service')
        $logger.AddExporter([FileExporter]::new($logFile))

        # Emit one message per severity level
        $logger.Trace('entering method Foo')
        $logger.Debug('parameter value: 42')
        $logger.Info('service started successfully')
        $logger.Warn('cache miss — falling back to database')
        $logger.Error('failed to connect to upstream API')
        $logger.Fatal('unrecoverable state — shutting down')

        $logger.Shutdown()

        # Every message produces exactly one JSON line
        $lines = Get-Content -Path $logFile
        $lines.Count | Should -Be 6

        # Each line is valid JSON
        foreach ($line in $lines)
        {
            { $line | ConvertFrom-Json } | Should -Not -Throw
        }

        # Severity levels are written in the correct order
        $records = $lines | ForEach-Object { $_ | ConvertFrom-Json }
        $records[0].severityText | Should -Be 'TRACE'
        $records[1].severityText | Should -Be 'DEBUG'
        $records[2].severityText | Should -Be 'INFO'
        $records[3].severityText | Should -Be 'WARN'
        $records[4].severityText | Should -Be 'ERROR'
        $records[5].severityText | Should -Be 'FATAL'
    }
}

# =============================================================================
# Example 2 — Distributed tracing: correlate logs with a W3C trace context
# =============================================================================

Describe 'Example 2 — Correlated logs via W3C TraceContext' -Tag 'Integration' {

    It 'all records within a request share the same traceId' {
        $logFile = Join-Path $TestDrive 'traced.jsonl'
        $logger  = [Logger]::new('api-gateway')
        $logger.AddExporter([FileExporter]::new($logFile))

        # Simulate an incoming request that carries a traceparent header
        $incomingTraceparent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        $ctx = [TraceContext]::new($incomingTraceparent)
        $logger.SetTraceContext($ctx)

        $logger.Info('request received: GET /api/orders')
        $logger.Debug('authorisation check passed')
        $logger.Info('query executed: 12 rows returned')
        $logger.Info('response sent: 200 OK')

        $logger.ClearTraceContext()
        $logger.Shutdown()

        $records = Get-Content -Path $logFile | ForEach-Object { $_ | ConvertFrom-Json }

        # Every record carries the same traceId from the incoming header
        foreach ($record in $records)
        {
            $record.traceId | Should -Be '4bf92f3577b34da6a3ce929d0e0e4736'
            $record.spanId  | Should -Be '00f067aa0ba902b7'
            $record.flags   | Should -Be 1
        }
    }

    It 'records logged after ClearTraceContext have empty traceId' {
        $logFile = Join-Path $TestDrive 'mixed-trace.jsonl'
        $logger  = [Logger]::new('worker')
        $logger.AddExporter([FileExporter]::new($logFile))

        $logger.SetTraceContext([TraceContext]::new())
        $logger.Info('inside request span')
        $logger.ClearTraceContext()
        $logger.Info('outside any span')

        $logger.Shutdown()

        $records = Get-Content -Path $logFile | ForEach-Object { $_ | ConvertFrom-Json }
        $records[0].traceId | Should -Not -BeNullOrEmpty
        $records[1].traceId | Should -Be ''
    }
}

# =============================================================================
# Example 3 — Resource attributes: tag logs with service and host metadata
# =============================================================================

Describe 'Example 3 — ResourceAttributes describe the emitting service' -Tag 'Integration' {

    It 'ResourceAttributes captures host, OS, PID, and runtime automatically' {
        $ra = [ResourceAttributes]::new('order-service')

        $ra.HasAttribute('service.name')             | Should -BeTrue
        $ra.HasAttribute('host.name')                | Should -BeTrue
        $ra.HasAttribute('os.type')                  | Should -BeTrue
        $ra.HasAttribute('process.pid')              | Should -BeTrue
        $ra.HasAttribute('process.runtime.name')     | Should -BeTrue
        $ra.HasAttribute('process.runtime.version')  | Should -BeTrue

        $ra.GetAttribute('service.name')         | Should -Be 'order-service'
        $ra.GetAttribute('process.runtime.name') | Should -Be 'PowerShell'
    }

    It 'custom attributes can be added to the resource' {
        $ra = [ResourceAttributes]::new('checkout')
        $ra.SetAttribute('deployment.environment', 'production')
        $ra.SetAttribute('service.version', '3.1.0')
        $ra.SetAttribute('cloud.region', 'eu-west-1')

        $ra.GetAttribute('deployment.environment') | Should -Be 'production'
        $ra.GetAttribute('service.version')        | Should -Be '3.1.0'
        $ra.GetAttribute('cloud.region')           | Should -Be 'eu-west-1'
    }

    It 'OTLP serialization produces the expected key-value structure' {
        $ra   = [ResourceAttributes]::new('payment-service')
        $otlp = $ra.ToOtlpAttributes()

        $serviceAttr = $otlp | Where-Object { $_.key -eq 'service.name' }
        $serviceAttr                    | Should -Not -BeNullOrEmpty
        $serviceAttr.value.stringValue  | Should -Be 'payment-service'

        $pidAttr = $otlp | Where-Object { $_.key -eq 'process.pid' }
        $pidAttr                 | Should -Not -BeNullOrEmpty
        $pidAttr.value.intValue  | Should -BeGreaterThan 0
    }
}

# =============================================================================
# Example 4 — Multiple exporters: fan-out to console and file simultaneously
# =============================================================================

Describe 'Example 4 — Fan-out to multiple exporters' -Tag 'Integration' {

    It 'a single Log call is delivered to every registered exporter' {
        $fileA = Join-Path $TestDrive 'exporter-a.jsonl'
        $fileB = Join-Path $TestDrive 'exporter-b.jsonl'

        $logger = [Logger]::new('fanout-service')
        $logger.AddExporter([FileExporter]::new($fileA))
        $logger.AddExporter([FileExporter]::new($fileB))

        $logger.Info('broadcast message')
        $logger.Warn('another broadcast')

        $logger.Shutdown()

        # Both files receive the same number of records
        (Get-Content -Path $fileA).Count | Should -Be 2
        (Get-Content -Path $fileB).Count | Should -Be 2

        # Both files carry the same body content
        $bodyA = (Get-Content -Path $fileA)[0] | ConvertFrom-Json | Select-Object -ExpandProperty body
        $bodyB = (Get-Content -Path $fileB)[0] | ConvertFrom-Json | Select-Object -ExpandProperty body
        $bodyA.stringValue | Should -Be $bodyB.stringValue
    }

    It 'removing an exporter stops delivery to that exporter only' {
        $fileA = Join-Path $TestDrive 'removed-a.jsonl'
        $fileB = Join-Path $TestDrive 'removed-b.jsonl'

        $logger = [Logger]::new('selective-service')
        $expA   = [FileExporter]::new($fileA)
        $expB   = [FileExporter]::new($fileB)
        $logger.AddExporter($expA)
        $logger.AddExporter($expB)

        $logger.Info('delivered to both')
        $logger.RemoveExporter($expA)
        $logger.Info('delivered to B only')

        $logger.Shutdown()

        (Get-Content -Path $fileA).Count | Should -Be 1
        (Get-Content -Path $fileB).Count | Should -Be 2
    }
}

# =============================================================================
# Example 5 — Metrics: introspect what the logger has emitted
# =============================================================================

Describe 'Example 5 — Logger metrics' -Tag 'Integration' {

    It 'TotalRecords reflects all Log calls regardless of severity' {
        $logger = [Logger]::new('metrics-svc')
        1..10 | ForEach-Object { $logger.Info("message $_") }
        $logger.GetMetrics().TotalRecords | Should -Be 10
    }

    It 'RecordsBySeverity breaks down counts per level' {
        $logger = [Logger]::new('breakdown-svc')
        $logger.Debug('d1'); $logger.Debug('d2'); $logger.Debug('d3')
        $logger.Info('i1');  $logger.Info('i2')
        $logger.Error('e1')

        $m = $logger.GetMetrics()
        $m.RecordsBySeverity.DEBUG | Should -Be 3
        $m.RecordsBySeverity.INFO  | Should -Be 2
        $m.RecordsBySeverity.ERROR | Should -Be 1
        $m.TotalRecords            | Should -Be 6
    }

    It 'ExportErrors counts failures without losing the record count' {
        $logger = [Logger]::new('error-svc')

        # Register a shut-down exporter that will reject every call
        $brokenExporter = [ConsoleExporter]::new()
        $brokenExporter.Shutdown()
        $logger.AddExporter($brokenExporter)

        $logger.Info('this export will fail')
        $logger.Warn('so will this one')

        $m = $logger.GetMetrics()
        $m.TotalRecords  | Should -Be 2
        $m.ExportErrors  | Should -Be 2
    }
}

# =============================================================================
# Example 6 — OTLP JSON output: validate the full log record schema
# =============================================================================

Describe 'Example 6 — OTLP JSON schema validation' -Tag 'Integration' {

    It 'a log record serialises to a schema-compliant OTLP JSON object' {
        $ctx    = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
        $record = [LogRecord]::new('user login succeeded', [OtelSeverity]::INFO, $ctx)
        $record.SetAttribute('user.id',        'u-1234')
        $record.SetAttribute('http.method',    'POST')
        $record.SetAttribute('http.status_code', 200)

        $json = $record.ToOtlpJson()
        $obj  = $json | ConvertFrom-Json

        # Required OTLP fields
        $obj.timeUnixNano           | Should -Not -BeNullOrEmpty
        $obj.observedTimeUnixNano   | Should -Not -BeNullOrEmpty
        $obj.severityNumber         | Should -Be 9
        $obj.severityText           | Should -Be 'INFO'
        $obj.body.stringValue       | Should -Be 'user login succeeded'
        $obj.traceId                | Should -Be '4bf92f3577b34da6a3ce929d0e0e4736'
        $obj.spanId                 | Should -Be '00f067aa0ba902b7'
        $obj.flags                  | Should -Be 1
        $obj.droppedAttributesCount | Should -Be 0

        # Attributes
        $userAttr = $obj.attributes | Where-Object { $_.key -eq 'user.id' }
        $userAttr.value.stringValue | Should -Be 'u-1234'

        $statusAttr = $obj.attributes | Where-Object { $_.key -eq 'http.status_code' }
        $statusAttr.value.intValue  | Should -Be 200
    }

    It 'OtlpHttpExporter wraps records in the ResourceLogs envelope' {
        $exp      = [OtlpHttpExporter]::new('http://otel-collector:4318')
        $records  = @(
            [LogRecord]::new('event A', [OtelSeverity]::INFO)
            [LogRecord]::new('event B', [OtelSeverity]::WARN)
        )
        $envelope = $exp.BuildEnvelope($records)

        # Top-level structure
        $envelope.resourceLogs                                     | Should -Not -BeNullOrEmpty
        $envelope.resourceLogs[0].scopeLogs                        | Should -Not -BeNullOrEmpty
        $envelope.resourceLogs[0].scopeLogs[0].scope.name          | Should -Be 'PSUltimateLog'
        $envelope.resourceLogs[0].scopeLogs[0].logRecords.Count    | Should -Be 2

        # Individual records are OTLP-compliant
        $first = $envelope.resourceLogs[0].scopeLogs[0].logRecords[0]
        $first.severityText       | Should -Be 'INFO'
        $first.body.stringValue   | Should -Be 'event A'
    }
}

# =============================================================================
# Example 7 — InstrumentationScope: identify the emitting library
# =============================================================================

Describe 'Example 7 — InstrumentationScope identifies the emitting library' -Tag 'Integration' {

    It 'scope name and version are preserved through OTLP serialization' {
        $scope = [InstrumentationScope]::new('PSUltimateLog', '0.1.0', 'https://opentelemetry.io/schemas/1.21.0')
        $scope.SetAttribute('telemetry.sdk.language', 'powershell')

        $otlp = $scope.ToOtlp()

        $otlp.name      | Should -Be 'PSUltimateLog'
        $otlp.version   | Should -Be '0.1.0'
        $otlp.schemaUrl | Should -Be 'https://opentelemetry.io/schemas/1.21.0'

        $langAttr = $otlp.attributes | Where-Object { $_.key -eq 'telemetry.sdk.language' }
        $langAttr.value.stringValue | Should -Be 'powershell'
    }

    It 'Logger auto-creates a scope named after the logger' {
        $logger = [Logger]::new('PSUltimateLog', [ResourceAttributes]::new('PSUltimateLog'))
        $logger.Scope.Name | Should -Be 'PSUltimateLog'
    }
}
