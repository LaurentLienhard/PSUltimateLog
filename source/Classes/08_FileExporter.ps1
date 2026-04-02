class FileExporter : LogExporter
{
    [string] $Path
    [bool]   $IsShutdown

    # Constructor: path to the target .jsonl file (created if it does not exist)
    FileExporter([string]$Path)
    {
        if ([string]::IsNullOrWhiteSpace($Path))
        {
            throw [System.ArgumentException]::new('Path cannot be null or empty.')
        }

        $this.Path       = $Path
        $this.IsShutdown = $false
    }

    # Appends each log record as a newline-delimited JSON line to the target file
    [void] Export([LogRecord[]]$Records)
    {
        if ($this.IsShutdown)
        {
            throw [System.InvalidOperationException]::new('FileExporter has been shut down.')
        }

        if ($null -eq $Records -or $Records.Count -eq 0)
        {
            return
        }

        foreach ($record in $Records)
        {
            Add-Content -Path $this.Path -Value $record.ToOtlpJson() -Encoding UTF8
        }
    }

    [void] Flush()
    {
        # File writes via Add-Content are synchronous; nothing to flush
    }

    [void] Shutdown()
    {
        $this.IsShutdown = $true
    }
}
