class Logger
{
    [LogFileWriter]$FileWriter
    [string]$ServiceName
    [string]$ServiceVersion
    [string]$HostName
    [string]$OsType
    [string]$TraceId
    [int]$ProcessId

    Logger(
        [string]$filePath,
        [string]$serviceName,
        [string]$serviceVersion,
        [string]$traceId
    )
    {
        $this.FileWriter = [LogFileWriter]::new($filePath)
        $this.ServiceName = $serviceName
        $this.ServiceVersion = $serviceVersion
        $this.HostName = [Environment]::MachineName
        $this.OsType = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        $this.TraceId = if ([string]::IsNullOrEmpty($traceId)) { [guid]::NewGuid().ToString() } else { $traceId }
        $this.ProcessId = [System.Diagnostics.Process]::GetCurrentProcess().Id
    }

    [void] Log(
        [string]$message,
        [LogLevel]$level,
        [bool]$emitVerbose,
        [hashtable]$additionalAttributes
    )
    {
        $resource = @{
            'service.name'     = $this.ServiceName
            'service.version'  = $this.ServiceVersion
            'host.name'        = $this.HostName
            'os.type'          = $this.OsType
            'process.pid'      = $this.ProcessId
            'process.runas'    = [Environment]::UserName
        }

        $attributes = if ($additionalAttributes -and $additionalAttributes.Count -gt 0)
        {
            $additionalAttributes.Clone()
        }
        else
        {
            @{}
        }

        $entry = [LogEntry]::new($message, $level, $this.TraceId, $resource, $attributes)
        $this.FileWriter.Write($entry)

        if ($emitVerbose)
        {
            Write-Verbose -Message $entry.ToVerboseString()
        }
    }
}
