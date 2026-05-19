class OtlpHttpExporter : LogExporter {
    [string]    $Endpoint
    hidden [hashtable] $_headers

    OtlpHttpExporter([string]$Endpoint) {
        $this.Endpoint  = $Endpoint.TrimEnd('/')
        $this._headers  = @{ 'Content-Type' = 'application/json' }
    }

    OtlpHttpExporter([string]$Endpoint, [hashtable]$Headers) {
        $this.Endpoint  = $Endpoint.TrimEnd('/')
        $merged         = @{}
        foreach ($kv in $Headers.GetEnumerator()) { $merged[$kv.Key] = $kv.Value }
        $merged['Content-Type'] = 'application/json'
        $this._headers  = $merged
    }

    # Returns the OTLP ResourceLogs envelope as a hashtable (not yet serialized)
    [hashtable] BuildEnvelope([LogRecord[]]$Records) {
        $logRecords = @($Records | ForEach-Object { $_.ToOtlpObject() })
        return @{
            resourceLogs = @(
                @{
                    resource  = @{ attributes = @() }
                    scopeLogs = @(
                        @{
                            scope      = @{ name = 'PSUltimateLog'; version = '0.0.1' }
                            logRecords = $logRecords
                        }
                    )
                }
            )
        }
    }

    [void] Export([LogRecord[]]$Records) {
        if ($this._isShutdown) {
            throw [System.InvalidOperationException]::new('Exporter has been shut down.')
        }
        $envelope = $this.BuildEnvelope($Records)
        $body     = $envelope | ConvertTo-Json -Depth 15 -Compress
        $uri      = "$($this.Endpoint)/v1/logs"
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $this._headers | Out-Null
    }
}
