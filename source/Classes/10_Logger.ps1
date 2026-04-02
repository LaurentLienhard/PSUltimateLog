class Logger
{
    [string]               $Name
    [TraceContext]          $TraceContext
    [ResourceAttributes]   $Resource
    [InstrumentationScope] $Scope
    hidden [System.Collections.Generic.List[LogExporter]] $_exporters
    hidden [hashtable]     $_metrics

    # Constructor: name only — auto-creates InstrumentationScope
    Logger([string]$Name)
    {
        $this.Initialize($Name)
        $this.Resource = $null
        $this.Scope    = [InstrumentationScope]::new($Name)
    }

    # Constructor: name and resource attributes
    Logger([string]$Name, [ResourceAttributes]$Resource)
    {
        $this.Initialize($Name)
        $this.Resource = $Resource
        $this.Scope    = [InstrumentationScope]::new($Name)
    }

    # Constructor: name, resource attributes, and instrumentation scope
    Logger([string]$Name, [ResourceAttributes]$Resource, [InstrumentationScope]$Scope)
    {
        $this.Initialize($Name)
        $this.Resource = $Resource
        $this.Scope    = if ($null -ne $Scope) { $Scope } else { [InstrumentationScope]::new($Name) }
    }

    hidden [void] Initialize([string]$Name)
    {
        if ([string]::IsNullOrWhiteSpace($Name))
        {
            throw [System.ArgumentException]::new('Logger name cannot be null or empty.')
        }

        $this.Name        = $Name
        $this.TraceContext = $null
        $this._exporters  = [System.Collections.Generic.List[LogExporter]]::new()
        $this._metrics    = @{
            TotalRecords      = 0
            ExportErrors      = 0
            RecordsBySeverity = @{
                TRACE = 0
                DEBUG = 0
                INFO  = 0
                WARN  = 0
                ERROR = 0
                FATAL = 0
            }
        }
    }

    # Adds an exporter to the pipeline
    [void] AddExporter([LogExporter]$Exporter)
    {
        if ($null -eq $Exporter)
        {
            throw [System.ArgumentNullException]::new('Exporter')
        }

        $this._exporters.Add($Exporter)
    }

    # Removes an exporter from the pipeline; does nothing if not found
    [void] RemoveExporter([LogExporter]$Exporter)
    {
        $this._exporters.Remove($Exporter) | Out-Null
    }

    # Returns the number of registered exporters
    [int] GetExporterCount()
    {
        return $this._exporters.Count
    }

    # Sets the active W3C trace context for all subsequent log records
    [void] SetTraceContext([TraceContext]$Context)
    {
        $this.TraceContext = $Context
    }

    # Clears the active trace context
    [void] ClearTraceContext()
    {
        $this.TraceContext = $null
    }

    # Emits a log record at the given severity through all registered exporters
    [void] Log([OtelSeverity]$Severity, [string]$Message)
    {
        $record = if ($null -ne $this.TraceContext)
        {
            [LogRecord]::new($Message, $Severity, $this.TraceContext)
        }
        else
        {
            [LogRecord]::new($Message, $Severity)
        }

        $this._metrics.TotalRecords++
        $this._metrics.RecordsBySeverity[$Severity.ToString()]++

        foreach ($exporter in $this._exporters)
        {
            try
            {
                $exporter.Export(@($record))
            }
            catch
            {
                $this._metrics.ExportErrors++
            }
        }
    }

    [void] Trace([string]$Message) { $this.Log([OtelSeverity]::TRACE, $Message) }
    [void] Debug([string]$Message) { $this.Log([OtelSeverity]::DEBUG, $Message) }
    [void] Info([string]$Message)  { $this.Log([OtelSeverity]::INFO,  $Message) }
    [void] Warn([string]$Message)  { $this.Log([OtelSeverity]::WARN,  $Message) }
    [void] Error([string]$Message) { $this.Log([OtelSeverity]::ERROR, $Message) }
    [void] Fatal([string]$Message) { $this.Log([OtelSeverity]::FATAL, $Message) }

    # Returns a snapshot of internal metrics (TotalRecords, ExportErrors, RecordsBySeverity)
    [hashtable] GetMetrics()
    {
        return @{
            TotalRecords      = $this._metrics.TotalRecords
            ExportErrors      = $this._metrics.ExportErrors
            RecordsBySeverity = $this._metrics.RecordsBySeverity.Clone()
        }
    }

    # Flushes all registered exporters; swallows individual exporter errors
    [void] Flush()
    {
        foreach ($exporter in $this._exporters)
        {
            try { $exporter.Flush() } catch { }
        }
    }

    # Shuts down all registered exporters; swallows individual exporter errors
    [void] Shutdown()
    {
        foreach ($exporter in $this._exporters)
        {
            try { $exporter.Shutdown() } catch { }
        }
    }
}
