[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because $ProjectName is used in the Describe block')]
param ()

$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object { $_.Directory.Name -eq 'source' }).BaseName

Import-Module $ProjectName

InModuleScope $ProjectName {
    Describe LogEntry {
        Context 'Type creation' {
            It 'Has created a type named LogEntry' {
                ([LogEntry] | Should -Not -BeNullOrEmpty)
            }
        }

        Context 'Constructor' {
            It 'Creates a LogEntry with correct properties' {
                $resource = @{ 'service.name' = 'TestApp'; 'service.version' = '1.0.0' }
                $attributes = @{ 'custom.key' = 'custom.value' }
                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, $resource, $attributes)

                $entry | Should -Not -BeNullOrEmpty
                $entry.Body | Should -Be 'Test message'
                $entry.Severity | Should -Be 'INFO'
                $entry.SeverityNumber | Should -Be 9
                $entry.Resource | Should -Be $resource
                $entry.Attributes | Should -Be $attributes
            }

            It 'Captures timestamp in UTC' {
                $entry = [LogEntry]::new('Test', [LogLevel]::Info, @{}, @{})
                $entry.Timestamp | Should -Not -BeNullOrEmpty
                $entry.Timestamp.Kind | Should -Be 'Utc'
            }

            It 'Maps LogLevel enum to correct severity string' {
                @(
                    @{ Level = [LogLevel]::Trace; Expected = 'TRACE' }
                    @{ Level = [LogLevel]::Debug; Expected = 'DEBUG' }
                    @{ Level = [LogLevel]::Info; Expected = 'INFO' }
                    @{ Level = [LogLevel]::Warning; Expected = 'WARNING' }
                    @{ Level = [LogLevel]::Error; Expected = 'ERROR' }
                    @{ Level = [LogLevel]::Fatal; Expected = 'FATAL' }
                ) | ForEach-Object {
                    $entry = [LogEntry]::new('Test', $_.Level, @{}, @{})
                    $entry.Severity | Should -Be $_.Expected
                }
            }
        }

        Context 'ToJson method' {
            It 'Returns valid JSON string' {
                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, @{ 'service.name' = 'TestApp' }, @{})
                $json = $entry.ToJson()

                { $json | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Includes all required fields in JSON' {
                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, @{ 'service.name' = 'TestApp' }, @{ 'key' = 'value' })
                $json = $entry.ToJson() | ConvertFrom-Json

                $json.timestamp | Should -Not -BeNullOrEmpty
                $json.severity | Should -Not -BeNullOrEmpty
                $json.severityNumber | Should -Not -BeNullOrEmpty
                $json.body | Should -Not -BeNullOrEmpty
                $json.resource | Should -Not -BeNullOrEmpty
                $json.attributes | Should -Not -BeNullOrEmpty
            }

            It 'Includes timestamp in JSON output' {
                $entry = [LogEntry]::new('Test', [LogLevel]::Info, @{}, @{})
                $json = $entry.ToJson() | ConvertFrom-Json

                # Verify timestamp is present
                $json.timestamp | Should -Not -BeNullOrEmpty
            }

            It 'Returns single-line JSON (no newlines)' {
                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, @{}, @{})
                $json = $entry.ToJson()

                $json | Should -Not -Match '`n|`r'
            }
        }

        Context 'ToVerboseString method' {
            It 'Returns formatted string with correct structure' {
                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, @{}, @{})
                $verbose = $entry.ToVerboseString()

                $verbose | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] Test message$'
            }

            It 'Includes timestamp, level, and message' {
                $entry = [LogEntry]::new('Processing complete', [LogLevel]::Error, @{}, @{})
                $verbose = $entry.ToVerboseString()

                $verbose | Should -Match 'ERROR'
                $verbose | Should -Match 'Processing complete'
            }
        }
    }
}
