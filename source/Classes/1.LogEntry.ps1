class LogEntry
{
    [datetime]$Timestamp
    [string]$Severity
    [int]$SeverityNumber
    [string]$Body
    [string]$TraceId
    [hashtable]$Resource
    [hashtable]$Attributes

    LogEntry(
        [string]$message,
        [LogLevel]$level,
        [string]$traceId,
        [hashtable]$resource,
        [hashtable]$attributes
    )
    {
        $this.Timestamp = [datetime]::UtcNow
        $this.Severity = $level.ToString().ToUpper()
        $this.SeverityNumber = [int]$level
        $this.Body = $message
        $this.TraceId = $traceId
        $this.Resource = $resource
        $this.Attributes = $attributes
    }

    [string] ToJson()
    {
        $jsonObject = @{
            timestamp       = $this.Timestamp.ToString('O')
            severity        = $this.Severity
            severityNumber  = $this.SeverityNumber
            body            = $this.Body
            traceId         = $this.TraceId
            resource        = $this.Resource
            attributes      = $this.Attributes
        }
        return ConvertTo-Json -InputObject $jsonObject -Compress -Depth 5
    }

    [string] ToVerboseString()
    {
        $dateString = $this.Timestamp.ToString('yyyy-MM-dd HH:mm:ss')
        return "[{0}] [{1}] {2}" -f $dateString, $this.Severity, $this.Body
    }
}
