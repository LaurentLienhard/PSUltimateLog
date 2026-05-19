class FileExporter : LogExporter {
    hidden [string] $_directory
    hidden [string] $_prefix
    hidden [string] $_fixedPath
    hidden [bool]   $_useRotation

    # Fixed path — writes all records to a single file
    FileExporter([string]$Path) {
        $this._fixedPath   = $Path
        $this._useRotation = $false
    }

    # Date-rotation — writes to <directory>/<prefix>-yyyy-MM-dd.jsonl
    FileExporter([string]$Directory, [string]$Prefix) {
        $this._directory   = $Directory
        $this._prefix      = $Prefix
        $this._useRotation = $true
    }

    hidden [string] _GetCurrentPath() {
        if ($this._useRotation) {
            $date = [System.DateTime]::UtcNow.ToString('yyyy-MM-dd')
            return [System.IO.Path]::Combine($this._directory, "$($this._prefix)-$date.jsonl")
        }
        return $this._fixedPath
    }

    [void] Export([LogRecord[]]$Records) {
        if ($this._isShutdown) {
            throw [System.InvalidOperationException]::new('Exporter has been shut down.')
        }
        $path = $this._GetCurrentPath()
        $dir  = [System.IO.Path]::GetDirectoryName($path)
        if (-not [string]::IsNullOrEmpty($dir) -and -not [System.IO.Directory]::Exists($dir)) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        }
        $lines = @($Records | ForEach-Object { $_.ToOtlpJson() })
        Add-Content -Path $path -Value $lines -Encoding UTF8
    }
}
