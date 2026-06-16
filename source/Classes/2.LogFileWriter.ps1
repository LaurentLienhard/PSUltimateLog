class LogFileWriter
{
    [string]$FilePath

    LogFileWriter([string]$filePath)
    {
        $resolvedPath = [System.IO.Path]::GetFullPath($filePath)
        $directory = [System.IO.Path]::GetDirectoryName($resolvedPath)

        if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -Path $directory))
        {
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        }

        $this.FilePath = $resolvedPath
    }

    [void] Write([LogEntry]$entry)
    {
        $jsonLine = $entry.ToJson()
        [System.IO.File]::AppendAllText($this.FilePath, $jsonLine + [System.Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
}
