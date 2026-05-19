class LogRecord {
    [string] $TimeUnixNano
    [string] $ObservedTimeUnixNano
    [int]    $SeverityNumber
    [string] $SeverityText
    [string] $Body
    [string] $TraceId
    [string] $SpanId
    [int]    $Flags
    [int]    $DroppedAttributesCount
    hidden [System.Collections.Generic.List[hashtable]] $_attributes

    LogRecord([string]$Body, [int]$SeverityNumber) {
        $this._Init($Body, $SeverityNumber, $null)
    }

    LogRecord([string]$Body, [int]$SeverityNumber, [TraceContext]$Context) {
        $this._Init($Body, $SeverityNumber, $Context)
    }

    hidden [void] _Init([string]$Body, [int]$SeverityNumber, [TraceContext]$Context) {
        $epochTicks = [System.Int64]621355968000000000
        $ticks      = [System.DateTime]::UtcNow.Ticks
        $nanos      = (([System.Int64]$ticks - $epochTicks) * [System.Int64]100)

        $this.TimeUnixNano          = $nanos.ToString()
        $this.ObservedTimeUnixNano  = $this.TimeUnixNano
        $this.SeverityNumber        = $SeverityNumber
        $this.SeverityText          = [OtelSeverity]::GetText($SeverityNumber)
        $this.Body                  = $Body
        $this.DroppedAttributesCount = 0
        $this._attributes           = [System.Collections.Generic.List[hashtable]]::new()

        if ($null -ne $Context) {
            $this.TraceId = $Context.TraceId
            $this.SpanId  = $Context.SpanId
            $this.Flags   = $Context.Flags
        }
        else {
            $this.TraceId = ''
            $this.SpanId  = ''
            $this.Flags   = 0
        }
    }

    [void] SetAttribute([string]$Key, [object]$Value) {
        # Remove existing entry with same key before adding updated one
        $existing = $this._attributes | Where-Object { $_.key -eq $Key }
        if ($existing) { $this._attributes.Remove($existing) | Out-Null }
        $valueObj = if ($Value -is [int] -or $Value -is [long]) {
            @{ intValue = $Value }
        }
        else {
            @{ stringValue = $Value.ToString() }
        }
        $this._attributes.Add(@{ key = $Key; value = $valueObj })
    }

    # Returns a hashtable representation (used by exporters that need an object, not a string)
    [hashtable] ToOtlpObject() {
        return [ordered]@{
            timeUnixNano           = $this.TimeUnixNano
            observedTimeUnixNano   = $this.ObservedTimeUnixNano
            severityNumber         = $this.SeverityNumber
            severityText           = $this.SeverityText
            body                   = @{ stringValue = $this.Body }
            traceId                = $this.TraceId
            spanId                 = $this.SpanId
            flags                  = $this.Flags
            droppedAttributesCount = $this.DroppedAttributesCount
            attributes             = $this._attributes.ToArray()
        }
    }

    # Returns a compressed OTLP-compliant JSON string
    [string] ToOtlpJson() {
        return $this.ToOtlpObject() | ConvertTo-Json -Depth 10 -Compress
    }
}
