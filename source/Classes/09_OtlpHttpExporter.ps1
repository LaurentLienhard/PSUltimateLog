class OtlpHttpExporter : LogExporter
{
    [string] $Endpoint
    [bool]   $IsShutdown

    # Constructor: base URL of the OTLP HTTP collector (e.g. http://localhost:4318)
    OtlpHttpExporter([string]$Endpoint)
    {
        if ([string]::IsNullOrWhiteSpace($Endpoint))
        {
            throw [System.ArgumentException]::new('Endpoint cannot be null or empty.')
        }

        $this.Endpoint   = $Endpoint.TrimEnd('/')
        $this.IsShutdown = $false
    }

    # POSTs log records to <Endpoint>/v1/logs wrapped in an OTLP ResourceLogs envelope
    [void] Export([LogRecord[]]$Records)
    {
        if ($this.IsShutdown)
        {
            throw [System.InvalidOperationException]::new('OtlpHttpExporter has been shut down.')
        }

        if ($null -eq $Records -or $Records.Count -eq 0)
        {
            return
        }

        $body = $this.BuildEnvelope($Records) | ConvertTo-Json -Depth 15 -Compress
        Invoke-RestMethod -Uri "$($this.Endpoint)/v1/logs" -Method Post -Body $body -ContentType 'application/json'
    }

    [void] Flush()
    {
        # HTTP calls are synchronous; nothing to flush
    }

    [void] Shutdown()
    {
        $this.IsShutdown = $true
    }

    # Builds the OTLP ResourceLogs > ScopeLogs > LogRecords JSON envelope
    [hashtable] BuildEnvelope([LogRecord[]]$Records)
    {
        $logRecords = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($record in $Records)
        {
            $logRecords.Add($record.ToOtlp())
        }

        return @{
            resourceLogs = @(
                @{
                    resource  = @{
                        attributes = @()
                    }
                    scopeLogs = @(
                        @{
                            scope      = @{
                                name    = 'PSUltimateLog'
                                version = ''
                            }
                            logRecords = $logRecords.ToArray()
                        }
                    )
                }
            )
        }
    }
}
