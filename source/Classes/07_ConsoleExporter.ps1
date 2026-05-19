class ConsoleExporter : LogExporter {
    hidden [hashtable] $_severityColors = @{
        TRACE = 'DarkGray'
        DEBUG = 'Cyan'
        INFO  = 'Green'
        WARN  = 'Yellow'
        ERROR = 'Red'
        FATAL = 'DarkRed'
    }

    [void] Export([LogRecord[]]$Records) {
        if ($this._isShutdown) {
            throw [System.InvalidOperationException]::new('Exporter has been shut down.')
        }
        foreach ($record in $Records) {
            $color = if ($this._severityColors.ContainsKey($record.SeverityText)) {
                $this._severityColors[$record.SeverityText]
            }
            else {
                'White'
            }
            Write-Host "[$($record.SeverityText)]  $($record.ToOtlpJson())" -ForegroundColor $color
        }
    }
}
