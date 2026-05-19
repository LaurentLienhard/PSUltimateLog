class LogExporter {
    hidden [bool] $_isShutdown = $false

    # Override in derived classes to handle one or more log records
    [void] Export([LogRecord[]]$Records) {
        throw [System.NotImplementedException]::new('Export must be overridden in a derived class.')
    }

    [void] Flush() {}

    [void] Shutdown() {
        $this._isShutdown = $true
    }

    [bool] IsShutdown() {
        return $this._isShutdown
    }
}
