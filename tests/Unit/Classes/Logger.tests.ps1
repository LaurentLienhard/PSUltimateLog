[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because $ProjectName is used in the Describe block')]
param ()

$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object { $_.Directory.Name -eq 'source' }).BaseName

Import-Module $ProjectName

InModuleScope $ProjectName {
    Describe Logger {
        Context 'Type creation' {
            It 'Has created a type named Logger' {
                ([Logger] | Should -Not -BeNullOrEmpty)
            }
        }

        Context 'Constructor' {
            It 'Initializes required properties' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $logger.ServiceName | Should -Be 'TestApp'
                $logger.ServiceVersion | Should -Be '1.0.0'
                $logger.FileWriter | Should -Not -BeNullOrEmpty
                $logger.HostName | Should -Not -BeNullOrEmpty
                $logger.OsType | Should -Not -BeNullOrEmpty
            }

            It 'Captures hostname' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $logger.HostName | Should -Not -BeNullOrEmpty
            }

            It 'Captures OS type' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $logger.OsType | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Log method' {
            It 'Writes entry to file' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'log.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $logger.Log('Test message', [LogLevel]::Info, $false, @{})

                Test-Path -Path $testFile | Should -Be $true
                (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 1
            }

            It 'Includes resource information in written entry' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'resource.jsonl'
                $logger = [Logger]::new($testFile, 'MyService', '2.5.0')

                $logger.Log('Test', [LogLevel]::Info, $false, @{})

                $content = Get-Content -Path $testFile | ConvertFrom-Json
                $content.resource.'service.name' | Should -Be 'MyService'
                $content.resource.'service.version' | Should -Be '2.5.0'
                $content.resource.'host.name' | Should -Not -BeNullOrEmpty
                $content.resource.'os.type' | Should -Not -BeNullOrEmpty
            }

            It 'Includes additional attributes in entry' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'attributes.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $attrs = @{ 'trace.id' = 'abc123'; 'user.id' = 'user456' }
                $logger.Log('Test', [LogLevel]::Info, $false, $attrs)

                $content = Get-Content -Path $testFile | ConvertFrom-Json
                $content.attributes.'trace.id' | Should -Be 'abc123'
                $content.attributes.'user.id' | Should -Be 'user456'
            }

            It 'Emits Write-Verbose when emitVerbose is true' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'verbose.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $VerbosePreference = 'Continue'
                $logger.Log('Test message', [LogLevel]::Warning, $true, @{}) 4>&1 | Out-Null
                $VerbosePreference = 'SilentlyContinue'
            }

            It 'Does not emit Write-Verbose when emitVerbose is false' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'noverbose.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                $VerbosePreference = 'Continue'
                $output = $logger.Log('Test message', [LogLevel]::Info, $false, @{}) 4>&1
                $VerbosePreference = 'SilentlyContinue'

                $output | Should -BeNullOrEmpty
            }

            It 'Handles empty attributes hashtable' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'empty.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                { $logger.Log('Test', [LogLevel]::Info, $false, @{}) } | Should -Not -Throw

                $content = Get-Content -Path $testFile | ConvertFrom-Json
                $content.attributes | Should -BeNullOrEmpty
            }

            It 'Works with multiple log levels' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'levels.jsonl'
                $logger = [Logger]::new($testFile, 'TestApp', '1.0.0')

                @(
                    @{ Level = [LogLevel]::Trace; Message = 'Trace' }
                    @{ Level = [LogLevel]::Debug; Message = 'Debug' }
                    @{ Level = [LogLevel]::Info; Message = 'Info' }
                    @{ Level = [LogLevel]::Warning; Message = 'Warning' }
                    @{ Level = [LogLevel]::Error; Message = 'Error' }
                    @{ Level = [LogLevel]::Fatal; Message = 'Fatal' }
                ) | ForEach-Object {
                    $logger.Log($_.Message, $_.Level, $false, @{})
                }

                (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 6
            }
        }
    }
}
