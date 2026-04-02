class LogRecord
{
    [string] $TimeUnixNano
    [string] $ObservedTimeUnixNano
    [int]    $SeverityNumber
    [string] $SeverityText
    [string] $Body
    [string] $TraceId
    [string] $SpanId
    [byte]   $Flags
    hidden [hashtable] $_attributes

    # Constructor: body and severity, no trace context
    LogRecord([string]$Body, [OtelSeverity]$Severity)
    {
        $this.Initialize($Body, $Severity)
        $this.TraceId = ''
        $this.SpanId  = ''
        $this.Flags   = 0
    }

    # Constructor: body, severity, and W3C trace context
    LogRecord([string]$Body, [OtelSeverity]$Severity, [TraceContext]$Context)
    {
        if ($null -eq $Context)
        {
            throw [System.ArgumentNullException]::new('Context')
        }

        $this.Initialize($Body, $Severity)
        $this.TraceId = $Context.TraceId
        $this.SpanId  = $Context.SpanId
        $this.Flags   = $Context.TraceFlags
    }

    hidden [void] Initialize([string]$Body, [OtelSeverity]$Severity)
    {
        $now = [LogRecord]::GetCurrentTimeUnixNano()

        $this.TimeUnixNano         = $now
        $this.ObservedTimeUnixNano = $now
        $this.SeverityNumber       = [int]$Severity
        $this.SeverityText         = $Severity.ToString()
        $this.Body                 = if ($null -ne $Body) { $Body } else { '' }
        $this._attributes          = @{}
    }

    # Sets or overwrites a log record attribute
    [void] SetAttribute([string]$Key, [object]$Value)
    {
        if ([string]::IsNullOrWhiteSpace($Key))
        {
            throw [System.ArgumentException]::new('Attribute key cannot be null or empty.')
        }

        $this._attributes[$Key] = $Value
    }

    # Returns the value of an attribute, or $null if not present
    [object] GetAttribute([string]$Key)
    {
        if ($this._attributes.ContainsKey($Key))
        {
            return $this._attributes[$Key]
        }

        return $null
    }

    # Returns true if the attribute key exists
    [bool] HasAttribute([string]$Key)
    {
        return $this._attributes.ContainsKey($Key)
    }

    # Serializes the log record to an OTLP-compliant hashtable
    [hashtable] ToOtlp()
    {
        return @{
            timeUnixNano           = $this.TimeUnixNano
            observedTimeUnixNano   = $this.ObservedTimeUnixNano
            severityNumber         = $this.SeverityNumber
            severityText           = $this.SeverityText
            body                   = @{ stringValue = $this.Body }
            traceId                = $this.TraceId
            spanId                 = $this.SpanId
            flags                  = [int]$this.Flags
            attributes             = $this.GetOtlpAttributes()
            droppedAttributesCount = 0
        }
    }

    # Serializes the log record to a compressed OTLP JSON string
    [string] ToOtlpJson()
    {
        return ($this.ToOtlp() | ConvertTo-Json -Depth 10 -Compress)
    }

    # Returns the current UTC time as nanoseconds since Unix epoch (string for JSON precision)
    static [string] GetCurrentTimeUnixNano()
    {
        # .NET ticks are 100ns intervals since Jan 1 0001
        # Unix epoch offset in ticks: 621355968000000000
        $nanos = ([System.DateTime]::UtcNow.Ticks - 621355968000000000L) * 100L
        return [string]$nanos
    }

    hidden [object[]] GetOtlpAttributes()
    {
        $result = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($key in $this._attributes.Keys)
        {
            $val = $this._attributes[$key]

            $otlpValue = switch ($val.GetType().Name)
            {
                'Int32'   { @{ intValue    = [long]$val } }
                'Int64'   { @{ intValue    = $val } }
                'Double'  { @{ doubleValue = $val } }
                'Boolean' { @{ boolValue   = $val } }
                default   { @{ stringValue = $val.ToString() } }
            }

            $result.Add(@{ key = $key; value = $otlpValue })
        }

        return $result.ToArray()
    }
}
