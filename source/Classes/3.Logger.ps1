class Logger
{
    [LogFileWriter]$FileWriter
    [string]$ServiceName
    [string]$ServiceVersion
    [string]$HostName
    [string]$OsType

    Logger(
        [string]$filePath,
        [string]$serviceName,
        [string]$serviceVersion
    )
    {
        $this.FileWriter = [LogFileWriter]::new($filePath)
        $this.ServiceName = $serviceName
        $this.ServiceVersion = $serviceVersion
        $this.HostName = if ([string]::IsNullOrEmpty($env:COMPUTERNAME)) { [System.Net.Dns]::GetHostName() } else { $env:COMPUTERNAME }
        $this.OsType = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    }

    [void] Log(
        [string]$message,
        [LogLevel]$level,
        [bool]$emitVerbose,
        [hashtable]$additionalAttributes
    )
    {
        $resource = @{
            'service.name'  = $this.ServiceName
            'service.version' = $this.ServiceVersion
            'host.name'     = $this.HostName
            'os.type'       = $this.OsType
        }

        $attributes = if ($additionalAttributes -and $additionalAttributes.Count -gt 0)
        {
            $additionalAttributes.Clone()
        }
        else
        {
            @{}
        }

        $entry = [LogEntry]::new($message, $level, $resource, $attributes)
        $this.FileWriter.Write($entry)

        if ($emitVerbose)
        {
            Write-Verbose -Message $entry.ToVerboseString()
        }
    }
}
