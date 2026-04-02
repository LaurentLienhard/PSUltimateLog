# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This module uses the **Sampler** framework with **InvokeBuild** and **ModuleBuilder**.

```powershell
# First-time setup: resolve dependencies (only needed once or when RequiredModules.psd1 changes)
./build.ps1 -ResolveDependency -Tasks noop

# Full build + test (default workflow)
./build.ps1

# Build only (no tests)
./build.ps1 -Tasks build

# Test only
./build.ps1 -Tasks test

# Run a single test file
./build.ps1 -Tasks test -PesterScript 'tests/Unit/Classes/MyClass.tests.ps1'

# Run tests with a specific tag
./build.ps1 -Tasks test -PesterTag 'Unit'
```

The built module is output to `output/module/PSUltimateLog/<version>/`.

## Architecture

### Source layout

- `source/Classes/` — PowerShell classes, **loaded in numeric prefix order** (e.g. `01_`, `02_`). Load order matters: base classes must have a lower prefix than derived classes.
- `source/Public/` — Exported functions (cmdlet wrappers over the classes)
- `source/Private/` — Internal helper functions
- `source/PSUltimateLog.psd1` — Module manifest (source version; ModuleBuilder generates the final one in `output/`)
- `source/PSUltimateLog.psm1` — Root module (intentionally empty; ModuleBuilder merges everything into it during build)

### Tests layout

- `tests/Unit/Classes/` — One test file per class, named `<ClassName>.tests.ps1`
- `tests/Unit/Public/` — Tests for public functions
- `tests/Unit/Private/` — Tests for private functions
- `tests/QA/module.tests.ps1` — Module-level QA tests (PSScriptAnalyzer, manifest, help)

Test files discover the module by scanning `*\*.psd1` and use `InModuleScope $ProjectName { }` to access internal classes.

### Module design intent

PSUltimateLog is an OpenTelemetry-compliant observability logging module. The class hierarchy (to be built) follows:

1. `OtelSeverity` — severity constants (TRACE=1, DEBUG=5, INFO=9, WARN=13, ERROR=17, FATAL=21)
2. `TraceContext` — W3C Trace Context (`traceparent`/`tracestate`), generates/parses 32-char TraceId and 16-char SpanId
3. `ResourceAttributes` — OTel Resource descriptor (`service.name`, `host.name`, `os.type`, `process.pid`...)
4. `InstrumentationScope` — Library/module that produced the log record
5. `LogRecord` — Core OTel log record; serializes to OTLP-compliant JSON
6. `LogExporter` — Abstract base exporter (`Export`, `Flush`, `Shutdown`)
7. `ConsoleExporter`, `FileExporter`, `OtlpHttpExporter` — Concrete exporters
8. `Logger` — Main facade; holds active `TraceContext`, list of exporters, and internal metrics counters

### JSON output format

Log records must serialize to the OTLP JSON schema (`timeUnixNano`, `severityNumber`, `severityText`, `body`, `traceId`, `spanId`, `attributes[]`, `resource`). The `FileExporter` writes newline-delimited JSON (`.jsonl`). The `OtlpHttpExporter` wraps records in the `ResourceLogs > ScopeLogs > LogRecords` envelope and POSTs to `/v1/logs`.

## Documentation

- **Always update `README.md`** after any code change — new classes, new public functions, behaviour changes, or new usage examples must be reflected immediately. The README is the primary reference for users of this module.

## Version control

- **Always run `git push` after committing** — every commit must be pushed to keep the GitHub repository in sync with local changes.

## Key constraints

- **Code coverage threshold is 85%** — enforced by the build pipeline (`build.yaml` → `CodeCoverageThreshold: 85`). New classes require corresponding Pester tests.
- **Class load order is controlled by numeric filename prefix** — always prefix class files (e.g. `01_OtelSeverity.ps1`, `02_TraceContext.ps1`). Derived classes must have a higher number than their base.
- **`source/PSUltimateLog.psm1` must remain empty** — ModuleBuilder merges all classes and functions into it at build time. Do not add code there directly.
- **PSScriptAnalyzer** runs as part of QA tests — settings in `.vscode/analyzersettings.psd1`.
