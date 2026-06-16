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

    .PARAMETER ScriptName
    The name of the script being executed (e.g. 'Install-CatoClient.ps1').
    Automatically added to log attributes as 'script.name'.

    .PARAMETER ActionStep
    The current step or phase within the script (e.g. 'Neutralization_Zscaler', 'Installation_MSI').
    Automatically added to log attributes as 'action.step'.

    .PARAMETER ErrorType
    In case of an error, the exception type (e.g. 'System.UnauthorizedAccessException').
    Automatically added to log attributes as 'error.type'.

    .PARAMETER Attributes
    A hashtable of additional custom key-value pairs for the log entry.
    Useful for application-specific data beyond the standard SysAdmin context.

    .EXAMPLE
    Write-LogEntry -Message 'Zscaler neutralized' -Level Info -ScriptName 'Install-CatoClient.ps1' -ActionStep 'Neutralization' -Verbose

    .EXAMPLE
    Write-LogEntry -Message 'Service started' -Level Info -ScriptName 'Deploy-Service.ps1' -ActionStep 'Service_Start' -Verbose

    .EXAMPLE
    try { Stop-Service CatoClient } catch { Write-LogEntry -Message "Failed to stop service" -Level Error -ErrorType $_.Exception.GetType().Name -Attributes @{ errorMessage = $_.Exception.Message } }

    .EXAMPLE
    'Processing' | Write-LogEntry -Level Info -Verbose

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
        [string]
        $ScriptName,

        [Parameter()]
        [string]
        $ActionStep,

        [Parameter()]
        [string]
        $ErrorType,

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

        $contextAttributes = $Attributes.Clone()

        if (-not [string]::IsNullOrEmpty($ScriptName))
        {
            $contextAttributes['script.name'] = $ScriptName
        }

        if (-not [string]::IsNullOrEmpty($ActionStep))
        {
            $contextAttributes['action.step'] = $ActionStep
        }

        if (-not [string]::IsNullOrEmpty($ErrorType))
        {
            $contextAttributes['error.type'] = $ErrorType
        }

        $shouldEmitVerbose = $PSBoundParameters.ContainsKey('Verbose') -or $VerbosePreference -eq 'Continue'
        $script:PSUltimateLogLogger.Log($Message, $Level, $shouldEmitVerbose, $contextAttributes)
    }
}
