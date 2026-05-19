class Logger {
    [InstrumentationScope] $Scope
    hidden [ResourceAttributes]  $_resource
    hidden [TraceContext]         $_traceContext
    hidden [System.Collections.Generic.List[LogExporter]] $_exporters
    hidden [int]       $_totalRecords  = 0
    hidden [int]       $_exportErrors  = 0
    hidden [hashtable] $_recordsBySeverity

    Logger([string]$ServiceName) {
        $this._Init($ServiceName, [ResourceAttributes]::new($ServiceName))
    }

    Logger([string]$ServiceName, [ResourceAttributes]$Resource) {
        $this._Init($ServiceName, $Resource)
    }

    hidden [void] _Init([string]$ServiceName, [ResourceAttributes]$Resource) {
        $this.Scope     = [InstrumentationScope]::new($ServiceName, '0.0.1')
        $this._resource = $Resource
        $this._exporters = [System.Collections.Generic.List[LogExporter]]::new()
        $this._traceContext = $null
        $this._recordsBySeverity = @{
            TRACE = 0; DEBUG = 0; INFO = 0
            WARN  = 0; ERROR = 0; FATAL = 0
        }
    }

    [void] AddExporter([LogExporter]$Exporter) {
        $this._exporters.Add($Exporter)
    }

    [void] RemoveExporter([LogExporter]$Exporter) {
        $this._exporters.Remove($Exporter) | Out-Null
    }

    [void] SetTraceContext([TraceContext]$Context) {
        $this._traceContext = $Context
    }

    [void] ClearTraceContext() {
        $this._traceContext = $null
    }

    hidden [void] _Log([string]$Message, [int]$Severity) {
        $record = if ($null -ne $this._traceContext) {
            [LogRecord]::new($Message, $Severity, $this._traceContext)
        }
        else {
            [LogRecord]::new($Message, $Severity)
        }

        $this._totalRecords++
        $text = [OtelSeverity]::GetText($Severity)
        if ($this._recordsBySeverity.ContainsKey($text)) {
            $this._recordsBySeverity[$text]++
        }

        foreach ($exporter in $this._exporters) {
            try {
                $exporter.Export(@($record))
            }
            catch {
                $this._exportErrors++
            }
        }
    }

    [void] Trace([string]$Message) { $this._Log($Message, [OtelSeverity]::TRACE) }
    [void] Debug([string]$Message) { $this._Log($Message, [OtelSeverity]::DEBUG) }
    [void] Info([string]$Message)  { $this._Log($Message, [OtelSeverity]::INFO)  }
    [void] Warn([string]$Message)  { $this._Log($Message, [OtelSeverity]::WARN)  }
    [void] Error([string]$Message) { $this._Log($Message, [OtelSeverity]::ERROR) }
    [void] Fatal([string]$Message) { $this._Log($Message, [OtelSeverity]::FATAL) }

    [PSCustomObject] GetMetrics() {
        return [PSCustomObject]@{
            TotalRecords      = $this._totalRecords
            ExportErrors      = $this._exportErrors
            RecordsBySeverity = $this._recordsBySeverity.Clone()
        }
    }

    [void] Shutdown() {
        foreach ($exporter in $this._exporters) {
            $exporter.Shutdown()
        }
    }
}
