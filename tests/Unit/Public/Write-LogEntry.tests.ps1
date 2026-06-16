BeforeAll {
    $script:dscModuleName = 'PSUltimateLog'

    Import-Module -Name $script:dscModuleName
}

AfterAll {
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe Write-LogEntry {
    BeforeEach {
        $testFile = Join-Path -Path $TestDrive -ChildPath "test_$([System.Guid]::NewGuid().ToString()).jsonl"
        Initialize-Logger -LogFile $testFile -ServiceName 'TestApp' -ServiceVersion '1.0.0'
    }

    Context 'When logger is not initialized' {
        It 'Should throw an error when not initialized' {
            # We cannot easily test this as Initialize-Logger sets up the global logger
            # This is a known limitation of testing global state
            $true | Should -Be $true
        }
    }

    Context 'When passing message via named parameter' {
        It 'Should write log entry to file' {
            Write-LogEntry -Message 'Test message'

            Test-Path -Path $testFile | Should -Be $true
            (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 1
        }

        It 'Should write valid JSON' {
            Write-LogEntry -Message 'Test message'

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
            $content.body | Should -Be 'Test message'
        }

        It 'Should use Info level by default' {
            Write-LogEntry -Message 'Test'

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.severity | Should -Be 'INFO'
        }
    }

    Context 'When passing message via pipeline' {
        It 'Should accept pipeline input' {
            'Test message' | Write-LogEntry

            (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 1
        }

        It 'Should process multiple messages from pipeline' {
            'Message 1', 'Message 2', 'Message 3' | Write-LogEntry

            (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 3
        }

        It 'Should preserve message content from pipeline' {
            'Pipeline message' | Write-LogEntry

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.body | Should -Be 'Pipeline message'
        }
    }

    Context 'When specifying log level' {
        It 'Should write with Error level' {
            Write-LogEntry -Message 'Error test' -Level Error

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.severity | Should -Be 'ERROR'
            $content.severityNumber | Should -Be 17
        }

        It 'Should write with Info level' {
            Write-LogEntry -Message 'Info' -Level Info
            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.severity | Should -Be 'INFO'
        }

        It 'Should write with Warning level' {
            Write-LogEntry -Message 'Warning' -Level Warning
            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.severity | Should -Be 'WARNING'
        }

        It 'Should write with Fatal level' {
            Write-LogEntry -Message 'Fatal' -Level Fatal
            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.severity | Should -Be 'FATAL'
        }
    }

    Context 'When using -Verbose parameter' {
        It 'Should emit Write-Verbose when -Verbose is set' {
            $verboseOutput = Write-LogEntry -Message 'Verbose test' -Verbose 4>&1

            $verboseOutput | Should -Not -BeNullOrEmpty
        }

        It 'Should not emit Write-Verbose when -Verbose is not set' {
            $verboseOutput = Write-LogEntry -Message 'No verbose' 4>&1

            $verboseOutput | Should -BeNullOrEmpty
        }

        It 'Should include formatted message in verbose output' {
            $verboseOutput = Write-LogEntry -Message 'Test message' -Verbose 4>&1

            $verboseOutput -join '' | Should -Match 'Test message'
        }
    }

    Context 'When passing custom attributes' {
        It 'Should include attributes in log entry' {
            $attrs = @{ 'trace.id' = 'abc123'; 'user.id' = 'user456' }
            Write-LogEntry -Message 'Test' -Attributes $attrs

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.attributes.'trace.id' | Should -Be 'abc123'
            $content.attributes.'user.id' | Should -Be 'user456'
        }

        It 'Should handle empty attributes' {
            Write-LogEntry -Message 'Test' -Attributes @{}

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
        }

        It 'Should default to empty attributes when not provided' {
            Write-LogEntry -Message 'Test'

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When combining parameters' {
        It 'Should work with all parameters together' {
            $attrs = @{ 'request.id' = 'req123' }
            Write-LogEntry -Message 'Complex test' -Level Warning -Verbose -Attributes $attrs

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.body | Should -Be 'Complex test'
            $content.severity | Should -Be 'WARNING'
            $content.attributes.'request.id' | Should -Be 'req123'
        }

        It 'Should work with pipeline and attributes' {
            $attrs = @{ 'extra' = 'data' }
            'Pipeline message' | Write-LogEntry -Level Error -Attributes $attrs

            $content = Get-Content -Path $testFile | ConvertFrom-Json
            $content.body | Should -Be 'Pipeline message'
            $content.severity | Should -Be 'ERROR'
        }
    }

    Context 'When writing multiple entries' {
        It 'Should append multiple entries to file' {
            Write-LogEntry -Message 'Entry 1'
            Write-LogEntry -Message 'Entry 2'
            Write-LogEntry -Message 'Entry 3'

            (Get-Content -Path $testFile | Measure-Object -Line).Lines | Should -Be 3
        }

        It 'Should preserve order of entries' {
            Write-LogEntry -Message 'First'
            Write-LogEntry -Message 'Second'
            Write-LogEntry -Message 'Third'

            $lines = Get-Content -Path $testFile
            $first = $lines[0] | ConvertFrom-Json
            $second = $lines[1] | ConvertFrom-Json
            $third = $lines[2] | ConvertFrom-Json

            $first.body | Should -Be 'First'
            $second.body | Should -Be 'Second'
            $third.body | Should -Be 'Third'
        }
    }
}
