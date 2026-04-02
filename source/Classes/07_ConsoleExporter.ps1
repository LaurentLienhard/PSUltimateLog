class ConsoleExporter : LogExporter
{
    [bool] $IsShutdown

    ConsoleExporter()
    {
        $this.IsShutdown = $false
    }

    # Writes each log record to the console as a formatted line
    [void] Export([LogRecord[]]$Records)
    {
        if ($this.IsShutdown)
        {
            throw [System.InvalidOperationException]::new('ConsoleExporter has been shut down.')
        }

        if ($null -eq $Records -or $Records.Count -eq 0)
        {
            return
        }

        foreach ($record in $Records)
        {
            $timestamp = [ConsoleExporter]::FormatTimestamp($record.TimeUnixNano)
            $severity  = $record.SeverityText.PadRight(5)
            Write-Host "[$timestamp] [$severity] $($record.Body)"
        }
    }

    [void] Flush()
    {
        # Console writes are synchronous; nothing to flush
    }

    [void] Shutdown()
    {
        $this.IsShutdown = $true
    }

    # Converts a nanosecond Unix timestamp string to a UTC ISO-8601 string
    static [string] FormatTimestamp([string]$TimeUnixNano)
    {
        try
        {
            $ticks = [long]$TimeUnixNano / 100L + 621355968000000000L
            $dt    = [System.DateTime]::new($ticks, [System.DateTimeKind]::Utc)
            return $dt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
        catch
        {
            return [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        }
    }
}
