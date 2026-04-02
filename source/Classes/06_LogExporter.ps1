class LogExporter
{
    # Exports a batch of log records. Must be overridden by derived classes.
    [void] Export([LogRecord[]]$Records)
    {
        throw [System.NotImplementedException]::new(
            "Export() must be implemented by derived class '$($this.GetType().Name)'."
        )
    }

    # Flushes any buffered records. Must be overridden by derived classes.
    [void] Flush()
    {
        throw [System.NotImplementedException]::new(
            "Flush() must be implemented by derived class '$($this.GetType().Name)'."
        )
    }

    # Shuts down the exporter and releases resources. Must be overridden by derived classes.
    [void] Shutdown()
    {
        throw [System.NotImplementedException]::new(
            "Shutdown() must be implemented by derived class '$($this.GetType().Name)'."
        )
    }
}
