class TraceContext
{
    [string] $TraceId
    [string] $SpanId
    [byte]   $TraceFlags
    [string] $TraceState

    # Generates a new random W3C Trace Context (sampled by default)
    TraceContext()
    {
        $this.TraceId    = [TraceContext]::GenerateTraceId()
        $this.SpanId     = [TraceContext]::GenerateSpanId()
        $this.TraceFlags = 1
        $this.TraceState = ''
    }

    # Parses an existing traceparent header
    TraceContext([string]$Traceparent)
    {
        $parsed          = [TraceContext]::ParseTraceparent($Traceparent)
        $this.TraceId    = $parsed.TraceId
        $this.SpanId     = $parsed.SpanId
        $this.TraceFlags = $parsed.TraceFlags
        $this.TraceState = ''
    }

    # Parses traceparent + tracestate headers
    TraceContext([string]$Traceparent, [string]$Tracestate)
    {
        $parsed          = [TraceContext]::ParseTraceparent($Traceparent)
        $this.TraceId    = $parsed.TraceId
        $this.SpanId     = $parsed.SpanId
        $this.TraceFlags = $parsed.TraceFlags
        $this.TraceState = $Tracestate
    }

    # Generates a random 32-char lowercase hex TraceId (16 bytes)
    static [string] GenerateTraceId()
    {
        $bytes = [byte[]]::new(16)
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        return [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower()
    }

    # Generates a random 16-char lowercase hex SpanId (8 bytes)
    static [string] GenerateSpanId()
    {
        $bytes = [byte[]]::new(8)
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        return [System.BitConverter]::ToString($bytes).Replace('-', '').ToLower()
    }

    # Parses a traceparent header string per W3C spec (version 00 only)
    static [hashtable] ParseTraceparent([string]$Traceparent)
    {
        if ([string]::IsNullOrWhiteSpace($Traceparent))
        {
            throw [System.ArgumentException]::new('traceparent cannot be null or empty.')
        }

        $parts = $Traceparent -split '-'

        if ($parts.Count -lt 4)
        {
            throw [System.FormatException]::new("Invalid traceparent format: '$Traceparent'.")
        }

        $version = $parts[0]
        $traceId = $parts[1]
        $spanId  = $parts[2]
        $flags   = $parts[3]

        if ($version -ne '00')
        {
            throw [System.FormatException]::new("Unsupported traceparent version: '$version'.")
        }

        if ($traceId -notmatch '^[0-9a-f]{32}$' -or $traceId -eq ('0' * 32))
        {
            throw [System.FormatException]::new("Invalid trace-id: '$traceId'.")
        }

        if ($spanId -notmatch '^[0-9a-f]{16}$' -or $spanId -eq ('0' * 16))
        {
            throw [System.FormatException]::new("Invalid parent-id: '$spanId'.")
        }

        if ($flags -notmatch '^[0-9a-f]{2}$')
        {
            throw [System.FormatException]::new("Invalid trace-flags: '$flags'.")
        }

        return @{
            TraceId    = $traceId
            SpanId     = $spanId
            TraceFlags = [System.Convert]::ToByte($flags, 16)
        }
    }

    # Returns the W3C traceparent header value for this context
    [string] ToTraceparent()
    {
        return '00-{0}-{1}-{2:x2}' -f $this.TraceId, $this.SpanId, $this.TraceFlags
    }

    # Returns true if the sampled flag (bit 0) is set
    [bool] IsSampled()
    {
        return ($this.TraceFlags -band 1) -eq 1
    }
}
