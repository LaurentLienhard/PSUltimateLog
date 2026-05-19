class TraceContext {
    [string] $TraceId
    [string] $SpanId
    [int]    $Flags
    [string] $TraceState

    # Generates a new TraceContext with random TraceId and SpanId
    TraceContext() {
        $this.TraceId    = [TraceContext]::_GenerateId(16)
        $this.SpanId     = [TraceContext]::_GenerateId(8)
        $this.Flags      = 1
        $this.TraceState = ''
    }

    # Parses an existing W3C traceparent string: '00-{traceId}-{spanId}-{flags}'
    TraceContext([string]$Traceparent) {
        $parsed          = [TraceContext]::_Parse($Traceparent)
        $this.TraceId    = $parsed.TraceId
        $this.SpanId     = $parsed.SpanId
        $this.Flags      = $parsed.Flags
        $this.TraceState = ''
    }

    hidden static [string] _GenerateId([int]$ByteCount) {
        $bytes = [byte[]]::new($ByteCount)
        $rng   = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        return ($bytes | ForEach-Object { '{0:x2}' -f $_ }) -join ''
    }

    hidden static [hashtable] _Parse([string]$Traceparent) {
        if ([string]::IsNullOrWhiteSpace($Traceparent)) {
            throw [System.ArgumentException]::new('Traceparent cannot be null or empty.')
        }
        $parts = $Traceparent -split '-'
        if ($parts.Count -lt 4 -or $parts[1].Length -ne 32 -or $parts[2].Length -ne 16) {
            throw [System.FormatException]::new("Invalid traceparent format: '$Traceparent'.")
        }
        return @{
            TraceId = $parts[1]
            SpanId  = $parts[2]
            Flags   = [System.Convert]::ToInt32($parts[3], 16)
        }
    }

    [string] ToTraceparent() {
        return '00-{0}-{1}-{2:x2}' -f $this.TraceId, $this.SpanId, $this.Flags
    }

    [bool] IsValid() {
        return ($this.TraceId -match '^[0-9a-f]{32}$') -and
               ($this.SpanId  -match '^[0-9a-f]{16}$')
    }
}
