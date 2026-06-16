function Write-LogEntry
{
    <#
    .SYNOPSIS
    Writes a structured log entry to the configured log file.

    .DESCRIPTION
    Writes a message to the JSONL log file with OpenTelemetry-compliant structured format.
    Optionally emits a simplified human-readable message to the PowerShell verbose stream.
    The logger must be initialized via Initialize-Logger before this function can be used.

    .PARAMETER Message
    The log message body. This will be included as the 'body' field in the JSON output.

    .PARAMETER Level
    The severity level of the log entry. Valid values are: Trace, Debug, Info, Warning, Error, Fatal.
    Default is Info.

    .PARAMETER Attributes
    A hashtable of additional key-value pairs to include in the log entry as the 'attributes' field.
    Useful for custom context such as trace IDs, span IDs, or application-specific data.

    .EXAMPLE
    Write-LogEntry -Message 'Application started' -Level Info -Verbose

    .EXAMPLE
    Write-LogEntry -Message 'User authentication failed' -Level Warning -Attributes @{ userId = 'user123'; reason = 'invalid_password' }

    .EXAMPLE
    'Processing item' | Write-LogEntry -Level Info -Verbose

    .NOTES
    Initialize-Logger must be called once per session before using Write-LogEntry.
    All timestamps are recorded in UTC (ISO 8601 format) for consistency across time zones and systems.

    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Module-specific logging function')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Message,

        [Parameter()]
        [LogLevel]
        $Level = [LogLevel]::Info,

        [Parameter()]
        [hashtable]
        $Attributes = @{}
    )

    process
    {
        if (-not $script:PSUltimateLogLogger)
        {
            throw "Logger not initialized. Call Initialize-Logger before using Write-LogEntry."
        }

        $shouldEmitVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -eq 'Continue'
        $script:PSUltimateLogLogger.Log($Message, $Level, $shouldEmitVerbose, $Attributes)
    }
}
