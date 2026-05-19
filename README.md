# PSUltimateLog

An OpenTelemetry-compliant structured logging module for PowerShell, designed to be consumed by other modules.

Log records follow the [OTLP JSON schema](https://opentelemetry.io/docs/specs/otlp/) and can be shipped to a console, a newline-delimited JSON file, or an OTLP HTTP collector. Multiple exporters can be active simultaneously (fan-out).

---

## Requirements

- PowerShell 5.0 or later
- No external dependencies

## Installation

```powershell
Install-Module -Name PSUltimateLog
```

## Quick start

```powershell
Import-Module PSUltimateLog

# Create a logger for your service
$logger = [Logger]::new('my-service')

# Add one or more exporters
$logger.AddExporter([ConsoleExporter]::new())
$logger.AddExporter([FileExporter]::new('C:\Logs', 'my-service'))  # date-rotation

# Emit structured log records
$logger.Info('Service started')
$logger.Warn('Cache miss — falling back to database')
$logger.Error('Failed to connect to upstream API')

# Clean up
$logger.Shutdown()
```

## Class reference

### OtelSeverity

Severity level constants aligned with the OpenTelemetry specification.

| Constant | Value |
|---|---|
| `TRACE` | 1 |
| `DEBUG` | 5 |
| `INFO`  | 9 |
| `WARN`  | 13 |
| `ERROR` | 17 |
| `FATAL` | 21 |

```powershell
[OtelSeverity]::INFO          # 9
[OtelSeverity]::GetText(9)    # 'INFO'
[OtelSeverity]::IsValid(9)    # True
```

### TraceContext

W3C Trace Context carrier. Generates or parses a `traceparent` header.

```powershell
# Generate new IDs
$ctx = [TraceContext]::new()
$ctx.TraceId       # 32-char hex
$ctx.SpanId        # 16-char hex
$ctx.ToTraceparent()  # '00-{traceId}-{spanId}-01'

# Parse incoming header
$ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
```

### ResourceAttributes

OTel resource descriptor. Auto-populates `service.name`, `host.name`, `os.type`, `process.pid`, `process.runtime.name`, and `process.runtime.version`.

```powershell
$ra = [ResourceAttributes]::new('my-service')
$ra.GetAttribute('host.name')
$ra.SetAttribute('deployment.environment', 'production')
$ra.ToOtlpAttributes()   # hashtable[] for OTLP serialization
```

### InstrumentationScope

Identifies the library or module that emitted the log.

```powershell
$scope = [InstrumentationScope]::new('PSUltimateLog', '1.0.0')
$scope = [InstrumentationScope]::new('PSUltimateLog', '1.0.0', 'https://opentelemetry.io/schemas/1.21.0')
$scope.SetAttribute('telemetry.sdk.language', 'powershell')
$scope.ToOtlp()
```

### LogRecord

Core OTLP log record. Accepts optional `TraceContext` for distributed tracing.

```powershell
$record = [LogRecord]::new('User logged in', [OtelSeverity]::INFO)
$record = [LogRecord]::new('User logged in', [OtelSeverity]::INFO, $ctx)
$record.SetAttribute('user.id', 'u-42')
$record.SetAttribute('http.status_code', 200)
$record.ToOtlpJson()    # compressed JSON string
$record.ToOtlpObject()  # hashtable (used by OtlpHttpExporter)
```

### LogExporter (abstract base)

Base class for all exporters. Override `Export([LogRecord[]])`.

```powershell
$exporter.Flush()
$exporter.Shutdown()
$exporter.IsShutdown()  # True after Shutdown()
```

### ConsoleExporter

Writes colorized OTLP JSON to the console. Color is determined by severity level.

```powershell
$logger.AddExporter([ConsoleExporter]::new())
```

### FileExporter

Writes newline-delimited JSON (`.jsonl`). Supports a fixed path or automatic date-rotation.

```powershell
# Fixed path
$logger.AddExporter([FileExporter]::new('C:\Logs\app.jsonl'))

# Date-rotation — creates app-2026-05-19.jsonl, app-2026-05-20.jsonl, ...
$logger.AddExporter([FileExporter]::new('C:\Logs', 'app'))
```

### OtlpHttpExporter

POSTs log records to an OTLP HTTP collector wrapped in the `ResourceLogs` envelope.

```powershell
$logger.AddExporter([OtlpHttpExporter]::new('http://otel-collector:4318'))

# With custom headers (e.g. authentication)
$logger.AddExporter([OtlpHttpExporter]::new('http://otel-collector:4318', @{
    'Authorization' = 'Bearer my-token'
}))
```

### Logger

Main facade. Holds an `InstrumentationScope`, optional `TraceContext`, a list of exporters, and internal metrics.

```powershell
# Minimal constructor
$logger = [Logger]::new('my-service')

# With explicit resource attributes
$ra = [ResourceAttributes]::new('my-service')
$ra.SetAttribute('deployment.environment', 'production')
$logger = [Logger]::new('my-service', $ra)

# Distributed tracing
$logger.SetTraceContext([TraceContext]::new($incomingTraceparent))
$logger.Info('Request received')
$logger.ClearTraceContext()

# Fan-out to multiple exporters
$logger.AddExporter([ConsoleExporter]::new())
$logger.AddExporter([FileExporter]::new('C:\Logs', 'svc'))
$logger.RemoveExporter($expToRemove)

# Log at any severity
$logger.Trace('Entering method Foo')
$logger.Debug('Parameter value: 42')
$logger.Info('Service started')
$logger.Warn('Retry attempt 2 of 3')
$logger.Error('Connection refused')
$logger.Fatal('Unrecoverable state — shutting down')

# Introspect metrics
$m = $logger.GetMetrics()
$m.TotalRecords              # total log calls
$m.RecordsBySeverity.INFO    # calls at INFO level
$m.ExportErrors              # export failures

$logger.Shutdown()
```

## Building from source

```powershell
# Resolve dependencies (first time only)
./build.ps1 -ResolveDependency -Tasks noop

# Full build and test
./build.ps1

# Tests only
./build.ps1 -Tasks test
```

## License

[MIT](LICENSE)
