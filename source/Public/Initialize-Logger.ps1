function Initialize-Logger
{
    <#
    .SYNOPSIS
    Initializes the global PSUltimateLog logger instance.

    .DESCRIPTION
    Creates and configures the module-level Logger instance that will be used for all subsequent
    Write-Log calls. Must be invoked once before any logging operations.

    .PARAMETER LogFile
    The path to the JSONL (newline-delimited JSON) file where log entries will be written.
    The parent directory will be created if it does not exist.

    .PARAMETER ServiceName
    The name of the service or application being logged. This will be included in every log entry
    as the resource.service.name field.

    .PARAMETER ServiceVersion
    The version of the service being logged. This will be included in every log entry
    as the resource.service.version field.

    .EXAMPLE
    Initialize-Logger -LogFile '/var/log/myapp/app.jsonl' -ServiceName 'MyApp' -ServiceVersion '1.0.0'

    .NOTES
    This function must be called before Write-Log or other logging functions can be used.
    The logger instance is stored in a module-scoped variable and persists for the lifetime
    of the PowerShell session.

    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $LogFile,

        [Parameter(Mandatory = $true)]
        [string]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [string]
        $ServiceVersion
    )

    process
    {
        $script:PSUltimateLogLogger = [Logger]::new($LogFile, $ServiceName, $ServiceVersion)
        Write-Verbose -Message "Logger initialized with service name '$ServiceName' version '$ServiceVersion' logging to '$LogFile'"
    }
}
