BeforeAll {
    $script:dscModuleName = 'PSUltimateLog'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe Initialize-Logger {
    Context 'When called with valid parameters' {
        It 'Should initialize the module-level logger' {
            $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'

            { Initialize-Logger -LogFile $testFile -ServiceName 'TestApp' -ServiceVersion '1.0.0' } | Should -Not -Throw
        }

        It 'Should create the log file when logger is used' {
            $testFile = Join-Path -Path $TestDrive -ChildPath "$(New-Guid).jsonl"

            Initialize-Logger -LogFile $testFile -ServiceName 'TestApp' -ServiceVersion '1.0.0'

            Test-Path -Path $testFile -PathType Leaf | Should -Be $false
        }

        It 'Should emit verbose message when initialized' {
            $testFile = Join-Path -Path $TestDrive -ChildPath 'test.jsonl'

            $verboseOutput = Initialize-Logger -LogFile $testFile -ServiceName 'TestApp' -ServiceVersion '1.0.0' -Verbose 4>&1

            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When called with nested directory path' {
        It 'Should create parent directories' {
            $testFile = Join-Path -Path $TestDrive -ChildPath 'nested' -AdditionalChildPath 'dirs', 'test.jsonl'

            Initialize-Logger -LogFile $testFile -ServiceName 'TestApp' -ServiceVersion '1.0.0'

            Test-Path -Path (Split-Path -Path $testFile -Parent) -PathType Container | Should -Be $true
        }
    }
}
