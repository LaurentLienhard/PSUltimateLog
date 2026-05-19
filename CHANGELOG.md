# Changelog for PSUltimateLog

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `OtelSeverity` class — OTel severity constants (TRACE=1, DEBUG=5, INFO=9, WARN=13, ERROR=17, FATAL=21) with `GetText()` and `IsValid()` helpers
- `TraceContext` class — W3C traceparent generation and parsing (32-char traceId, 16-char spanId, flags), cryptographically random IDs
- `ResourceAttributes` class — OTel resource descriptor with auto-populated `service.name`, `host.name`, `os.type`, `process.pid`, `process.runtime.name/version`; `HasAttribute`, `GetAttribute`, `SetAttribute`, `ToOtlpAttributes`
- `InstrumentationScope` class — library name/version/schemaUrl holder with `SetAttribute` and `ToOtlp`
- `LogRecord` class — core OTel log record; Unix-nano timestamp, body, severity, trace context binding, per-attribute type inference (string/int); `ToOtlpObject` and `ToOtlpJson`
- `LogExporter` abstract base class — `Export`, `Flush`, `Shutdown`, `IsShutdown`
- `ConsoleExporter` — writes colorized OTLP JSON to console, one color per severity level
- `FileExporter` — writes newline-delimited JSON (`.jsonl`); supports fixed path or date-rotation (`prefix-yyyy-MM-dd.jsonl`)
- `OtlpHttpExporter` — builds OTLP `ResourceLogs` envelope and POSTs to `/v1/logs`; optional custom headers
- `Logger` facade — holds `InstrumentationScope`, `ResourceAttributes`, active `TraceContext`; fan-out to multiple exporters; `Trace/Debug/Info/Warn/Error/Fatal` methods; per-severity metrics via `GetMetrics()`
- Pester unit tests for all 10 classes (coverage target 70%)

### Changed

- Reset project to blank slate — removed previous class implementations
- Added coding standards to CLAUDE.md: English-only, class-first design, comment-based help with 4+ examples, mandatory README and CHANGELOG update before each commit
- Code coverage threshold lowered to 70% in `build.yaml`

