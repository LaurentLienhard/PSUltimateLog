[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Suppressing this rule because $ProjectName is used in the Describe block')]
param ()

$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object { $_.Directory.Name -eq 'source' }).BaseName

Import-Module $ProjectName

InModuleScope $ProjectName {
    Describe LogFileWriter {
        Context 'Type creation' {
            It 'Has created a type named LogFileWriter' {
                ([LogFileWriter] | Should -Not -BeNullOrEmpty)
            }
        }

        Context 'Constructor' {
            It 'Accepts a file path and resolves it' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'
                $writer = [LogFileWriter]::new($testFile)

                $writer.FilePath | Should -Not -BeNullOrEmpty
            }

            It 'Creates parent directory if it does not exist' {
                $testDir = Join-Path -Path $TestDrive -ChildPath 'nested' -AdditionalChildPath 'dir'
                $testFile = Join-Path -Path $testDir -ChildPath 'test.jsonl'

                $writer = [LogFileWriter]::new($testFile)

                Test-Path -Path $testDir -PathType Container | Should -Be $true
            }

            It 'Does not fail if parent directory already exists' {
                $testDir = Join-Path -Path $TestDrive -ChildPath 'existing'
                New-Item -Path $testDir -ItemType Directory -Force | Out-Null

                $testFile = Join-Path -Path $testDir -ChildPath 'test.jsonl'

                { [LogFileWriter]::new($testFile) } | Should -Not -Throw
            }
        }

        Context 'Write method' {
            It 'Creates the log file on first write' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'newfile.jsonl'
                $writer = [LogFileWriter]::new($testFile)

                $entry = [LogEntry]::new('Test message', [LogLevel]::Info, @{}, @{})
                $writer.Write($entry)

                Test-Path -Path $testFile | Should -Be $true
            }

            It 'Appends JSON to the file' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'append.jsonl'
                $writer = [LogFileWriter]::new($testFile)

                $entry1 = [LogEntry]::new('Message 1', [LogLevel]::Info, @{}, @{})
                $entry2 = [LogEntry]::new('Message 2', [LogLevel]::Error, @{}, @{})

                $writer.Write($entry1)
                $writer.Write($entry2)

                $content = Get-Content -Path $testFile
                $content.Count | Should -Be 2
            }

            It 'Writes valid JSON lines' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'valid.jsonl'
                $writer = [LogFileWriter]::new($testFile)

                $entry = [LogEntry]::new('Test', [LogLevel]::Info, @{}, @{})
                $writer.Write($entry)

                $line = Get-Content -Path $testFile -Raw
                { $line | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Writes with UTF-8 encoding' {
                $testFile = Join-Path -Path $TestDrive -ChildPath 'encoding.jsonl'
                $writer = [LogFileWriter]::new($testFile)

                $entry = [LogEntry]::new('Ü unicode test', [LogLevel]::Info, @{}, @{})
                $writer.Write($entry)

                $line = Get-Content -Path $testFile -Encoding UTF8 -Raw
                $line | Should -Match 'unicode test'
            }
        }
    }
}
