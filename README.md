# PSUltimateLog

An **OpenTelemetry-compliant** observability logging module for PowerShell.

PSUltimateLog emits structured log records in the [OTLP JSON](https://opentelemetry.io/docs/specs/otlp/) format, supports W3C Trace Context propagation, and ships records to one or more exporters (console, file, or an OTLP HTTP collector) through a simple facade.

---

## Table of contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Core concepts](#core-concepts)
- [Class reference](#class-reference)
  - [OtelSeverity](#otelseverity)
  - [TraceContext](#tracecontext)
  - [ResourceAttributes](#resourceattributes)
  - [InstrumentationScope](#instrumentationscope)
  - [LogRecord](#logrecord)
  - [LogExporter](#logexporter)
  - [ConsoleExporter](#consoleexporter)
  - [FileExporter](#fileexporter)
  - [OtlpHttpExporter](#otlphttpexporter)
  - [Logger](#logger)
- [Usage examples](#usage-examples)
- [OTLP JSON schema](#otlp-json-schema)
- [Building from source](#building-from-source)
- [Running tests](#running-tests)
- [Contributing](#contributing)
- [License](#license)

---

## Requirements

| Requirement | Minimum |
|---|---|
| PowerShell | 5.0 (Desktop) or 7.x (Core) |
| .NET Framework | 4.6.2+ (PS 5) / .NET 6+ (PS 7) |

---

## Installation

```powershell
# From the PowerShell Gallery (once published)
Install-Module -Name PSUltimateLog

# From source
./build.ps1 -ResolveDependency -Tasks noop   # first-time setup
./build.ps1 -Tasks build
Import-Module ./output/module/PSUltimateLog/0.0.1/PSUltimateLog.psd1
```

---

## Quick start

```powershell
Import-Module PSUltimateLog

# 1 — Create a logger
$logger = [Logger]::new('my-service')

# 2 — Add an exporter
$logger.AddExporter([ConsoleExporter]::new())

# 3 — Log messages
$logger.Info('service started')
$logger.Warn('cache miss')
$logger.Error('upstream timeout')

# 4 — Flush and shut down cleanly
$logger.Flush()
$logger.Shutdown()
```

Console output:

```
[2026-04-02T10:00:00.000Z] [INFO ] service started
[2026-04-02T10:00:00.001Z] [WARN ] cache miss
[2026-04-02T10:00:00.002Z] [ERROR] upstream timeout
```

---

## Core concepts

```
Logger
 ├── TraceContext      (W3C traceparent / tracestate)
 ├── ResourceAttributes (service.name, host.name, os.type, process.pid …)
 ├── InstrumentationScope (library name + version)
 └── Exporters [ ]
      ├── ConsoleExporter
      ├── FileExporter      → newline-delimited JSON (.jsonl)
      └── OtlpHttpExporter  → POST /v1/logs (OTLP JSON envelope)
```

Each `Log` call produces a `LogRecord` that is pushed through every registered exporter. Export failures are caught silently and counted in the logger metrics — they never crash the calling code.

---

## Class reference

### OtelSeverity

PowerShell enum with the six standard OpenTelemetry severity levels.

| Name | Value |
|------|------:|
| `TRACE` | 1 |
| `DEBUG` | 5 |
| `INFO` | 9 |
| `WARN` | 13 |
| `ERROR` | 17 |
| `FATAL` | 21 |

```powershell
[OtelSeverity]::INFO        # enum member
[int][OtelSeverity]::WARN   # 13
[OtelSeverity]9             # INFO
```

---

### TraceContext

Implements [W3C Trace Context](https://www.w3.org/TR/trace-context/) (`traceparent` / `tracestate`).

| Property | Type | Description |
|----------|------|-------------|
| `TraceId` | `string` | 32-char lowercase hex (16 bytes) |
| `SpanId` | `string` | 16-char lowercase hex (8 bytes) |
| `TraceFlags` | `byte` | Bit flags (bit 0 = sampled) |
| `TraceState` | `string` | Vendor-specific key-value pairs |

```powershell
# New random context
$ctx = [TraceContext]::new()

# Parse an incoming traceparent header
$ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')

# Parse traceparent + tracestate
$ctx = [TraceContext]::new($traceparent, $tracestate)

# Serialize back to a header value
$ctx.ToTraceparent()   # '00-4bf92f...-00f067...-01'

# Check sampling flag
$ctx.IsSampled()       # $true
```

---

### ResourceAttributes

Describes the entity (service, host, process) producing the telemetry.  
Auto-populates `host.name`, `os.type`, `process.pid`, `process.runtime.name`, and `process.runtime.version` on construction.

```powershell
# With service name
$ra = [ResourceAttributes]::new('order-service')

# Add custom attributes
$ra.SetAttribute('deployment.environment', 'production')
$ra.SetAttribute('service.version', '2.1.0')
$ra.SetAttribute('cloud.region', 'eu-west-1')

# Query
$ra.GetAttribute('host.name')
$ra.HasAttribute('os.type')    # $true
$ra.RemoveAttribute('cloud.region')
$ra.GetKeys()

# Serialize to OTLP key-value array
$ra.ToOtlpAttributes()
# @( @{key='service.name'; value=@{stringValue='order-service'}}, … )
```

---

### InstrumentationScope

Identifies the library or component that produced the log record.

```powershell
$scope = [InstrumentationScope]::new('PSUltimateLog', '0.1.0', 'https://opentelemetry.io/schemas/1.21.0')
$scope.SetAttribute('telemetry.sdk.language', 'powershell')

$scope.ToOtlp()
# @{ name='PSUltimateLog'; version='0.1.0'; schemaUrl='…'; attributes=@(…); droppedAttributesCount=0 }
```

---

### LogRecord

Core OTel log record. Created automatically by `Logger` — you rarely need to instantiate it directly.

| Property | Type | Description |
|----------|------|-------------|
| `TimeUnixNano` | `string` | UTC timestamp in nanoseconds since Unix epoch |
| `ObservedTimeUnixNano` | `string` | Observation time (same as `TimeUnixNano` on creation) |
| `SeverityNumber` | `int` | Numeric severity (from `OtelSeverity`) |
| `SeverityText` | `string` | Severity name (`INFO`, `WARN` …) |
| `Body` | `string` | Log message |
| `TraceId` | `string` | 32-char hex, empty if no context |
| `SpanId` | `string` | 16-char hex, empty if no context |
| `Flags` | `byte` | W3C trace flags |

```powershell
# Without trace context
$record = [LogRecord]::new('payment processed', [OtelSeverity]::INFO)

# With trace context
$record = [LogRecord]::new('payment processed', [OtelSeverity]::INFO, $ctx)

# Add attributes
$record.SetAttribute('payment.id',     'pay-9876')
$record.SetAttribute('amount.cents',   1999)
$record.SetAttribute('currency',       'EUR')

# Serialize
$record.ToOtlpJson()   # compressed OTLP JSON string
$record.ToOtlp()       # hashtable
```

---

### LogExporter

Abstract base class. All exporters inherit from it and must implement `Export`, `Flush`, and `Shutdown`.

```powershell
class MyExporter : LogExporter {
    [void] Export([LogRecord[]]$Records) { <# … #> }
    [void] Flush()                       { <# … #> }
    [void] Shutdown()                    { <# … #> }
}
```

---

### ConsoleExporter

Writes formatted log lines to the PowerShell host.

Output format: `[2026-04-02T10:00:00.000Z] [INFO ] message body`

```powershell
$exp = [ConsoleExporter]::new()
$exp.Export(@($record))
$exp.Flush()
$exp.Shutdown()

# Static helper — convert nanosecond timestamp to ISO-8601 string
[ConsoleExporter]::FormatTimestamp($record.TimeUnixNano)
```

---

### FileExporter

Appends log records as **newline-delimited JSON** (`.jsonl`) to a file. Each line is a self-contained OTLP JSON object. The file is created if it does not exist.

```powershell
$exp = [FileExporter]::new('C:\logs\app.jsonl')
$exp.Export(@($record))
$exp.Flush()      # no-op — Add-Content is synchronous
$exp.Shutdown()   # blocks further exports
```

Resulting file:

```jsonl
{"timeUnixNano":"1743587200000000000","severityNumber":9,"severityText":"INFO","body":{"stringValue":"service started"},...}
{"timeUnixNano":"1743587200100000000","severityNumber":13,"severityText":"WARN","body":{"stringValue":"cache miss"},...}
```

---

### OtlpHttpExporter

POSTs log records to an [OTLP HTTP](https://opentelemetry.io/docs/specs/otlp/#otlphttp) collector endpoint, wrapped in the `ResourceLogs > ScopeLogs > LogRecords` envelope.

```powershell
$exp = [OtlpHttpExporter]::new('http://localhost:4318')
$exp.Export(@($record))   # POST to http://localhost:4318/v1/logs
$exp.Flush()
$exp.Shutdown()

# Inspect the envelope without sending
$exp.BuildEnvelope(@($record))
```

OTLP envelope structure:

```json
{
  "resourceLogs": [{
    "resource":  { "attributes": [] },
    "scopeLogs": [{
      "scope":      { "name": "PSUltimateLog", "version": "" },
      "logRecords": [ { … }, { … } ]
    }]
  }]
}
```

---

### Logger

Main facade. Manages exporters, propagates `TraceContext`, and tracks metrics.

#### Constructors

```powershell
[Logger]::new('service-name')
[Logger]::new('service-name', $resourceAttributes)
[Logger]::new('service-name', $resourceAttributes, $instrumentationScope)
```

#### Exporter management

```powershell
$logger.AddExporter([ConsoleExporter]::new())
$logger.AddExporter([FileExporter]::new('app.jsonl'))
$logger.RemoveExporter($exp)
$logger.GetExporterCount()   # 2
```

#### Trace context

```powershell
$logger.SetTraceContext([TraceContext]::new($incomingTraceparent))
# … log correlated messages …
$logger.ClearTraceContext()
```

#### Logging

```powershell
$logger.Log([OtelSeverity]::INFO, 'generic call')

# Convenience methods
$logger.Trace('entering Foo')
$logger.Debug('x = 42')
$logger.Info('order created')
$logger.Warn('retry attempt 2/3')
$logger.Error('database timeout')
$logger.Fatal('unrecoverable — aborting')
```

#### Metrics

```powershell
$m = $logger.GetMetrics()
$m.TotalRecords               # 42
$m.ExportErrors               # 0
$m.RecordsBySeverity.INFO     # 30
$m.RecordsBySeverity.ERROR    # 2
```

#### Lifecycle

```powershell
$logger.Flush()      # flushes all exporters
$logger.Shutdown()   # shuts down all exporters
```

---

## Usage examples

### Structured logging to a file

```powershell
$logger = [Logger]::new('api-service')
$logger.AddExporter([FileExporter]::new('C:\logs\api.jsonl'))

$logger.Info('server listening on :8080')

$record = [LogRecord]::new('request received', [OtelSeverity]::INFO)
$record.SetAttribute('http.method',      'POST')
$record.SetAttribute('http.target',      '/api/orders')
$record.SetAttribute('http.status_code', 201)
$logger.Log([OtelSeverity]::INFO, 'request received')

$logger.Shutdown()
```

### Distributed tracing — propagate an incoming trace

```powershell
# Incoming HTTP request carries a traceparent header
$incomingHeader = $request.Headers['traceparent']

$logger = [Logger]::new('order-service')
$logger.AddExporter([FileExporter]::new('orders.jsonl'))
$logger.SetTraceContext([TraceContext]::new($incomingHeader))

$logger.Info('order validation started')
$logger.Debug('stock check: OK')
$logger.Info('order persisted — id: ord-5678')

$logger.ClearTraceContext()
$logger.Shutdown()
```

### Full service setup with resource metadata

```powershell
$resource = [ResourceAttributes]::new('checkout-service')
$resource.SetAttribute('service.version',         '1.4.2')
$resource.SetAttribute('deployment.environment',  'production')

$scope = [InstrumentationScope]::new('PSUltimateLog', '0.1.0')

$logger = [Logger]::new('checkout-service', $resource, $scope)
$logger.AddExporter([ConsoleExporter]::new())
$logger.AddExporter([FileExporter]::new('C:\logs\checkout.jsonl'))

$logger.Info('checkout pipeline ready')
```

### Send logs to an OpenTelemetry Collector

```powershell
$logger = [Logger]::new('payment-service')
$logger.AddExporter([OtlpHttpExporter]::new('http://otel-collector:4318'))

$logger.Info('payment authorised')
$logger.Error('refund failed — gateway timeout')

$logger.Flush()
$logger.Shutdown()
```

### Fan-out: console in development, file + collector in production

```powershell
$logger = [Logger]::new('worker-service')

if ($env:ENVIRONMENT -eq 'production')
{
    $logger.AddExporter([FileExporter]::new('/var/log/worker.jsonl'))
    $logger.AddExporter([OtlpHttpExporter]::new('http://otel-collector:4318'))
}
else
{
    $logger.AddExporter([ConsoleExporter]::new())
}

$logger.Info('worker started')
```

---

## OTLP JSON schema

Every log record serialised by `ToOtlpJson()` conforms to the following shape:

```json
{
  "timeUnixNano":           "1743587200000000000",
  "observedTimeUnixNano":   "1743587200000000000",
  "severityNumber":         9,
  "severityText":           "INFO",
  "body":                   { "stringValue": "order created" },
  "traceId":                "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId":                 "00f067aa0ba902b7",
  "flags":                  1,
  "attributes": [
    { "key": "order.id",    "value": { "stringValue": "ord-1234" } },
    { "key": "amount",      "value": { "intValue": 4999 } },
    { "key": "paid",        "value": { "boolValue": true } }
  ],
  "droppedAttributesCount": 0
}
```

Attribute value types: `stringValue`, `intValue`, `doubleValue`, `boolValue`.

---

## Building from source

```powershell
# First-time setup (resolves dependencies from RequiredModules.psd1)
./build.ps1 -ResolveDependency -Tasks noop

# Full build + tests
./build.ps1

# Build only
./build.ps1 -Tasks build

# Output: output/module/PSUltimateLog/<version>/
```

---

## Running tests

```powershell
# All tests
./build.ps1 -Tasks test

# Unit tests only
./build.ps1 -Tasks test -PesterTag 'Unit'

# Integration tests only
./build.ps1 -Tasks test -PesterTag 'Integration'

# Single class
./build.ps1 -Tasks test -PesterScript 'tests/Unit/Classes/Logger.tests.ps1'
```

Code coverage threshold: **85%** (enforced by the build pipeline).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

Copyright © LIENHARD Laurent. All rights reserved.
