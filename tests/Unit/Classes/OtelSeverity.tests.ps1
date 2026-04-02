BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'OtelSeverity' -Tag 'Unit' {

    Context 'Severity values' {

        It 'TRACE should equal 1' {
            [int][OtelSeverity]::TRACE | Should -Be 1
        }

        It 'DEBUG should equal 5' {
            [int][OtelSeverity]::DEBUG | Should -Be 5
        }

        It 'INFO should equal 9' {
            [int][OtelSeverity]::INFO | Should -Be 9
        }

        It 'WARN should equal 13' {
            [int][OtelSeverity]::WARN | Should -Be 13
        }

        It 'ERROR should equal 17' {
            [int][OtelSeverity]::ERROR | Should -Be 17
        }

        It 'FATAL should equal 21' {
            [int][OtelSeverity]::FATAL | Should -Be 21
        }
    }

    Context 'Enum behavior' {

        It 'should parse a valid severity name' {
            [OtelSeverity]'INFO' | Should -Be ([OtelSeverity]::INFO)
        }

        It 'should cast an int to the correct severity' {
            [OtelSeverity]9 | Should -Be ([OtelSeverity]::INFO)
        }

        It 'should return the severity name as string' {
            ([OtelSeverity]::WARN).ToString() | Should -Be 'WARN'
        }

        It 'should contain exactly 6 members' {
            [System.Enum]::GetNames([OtelSeverity]).Count | Should -Be 6
        }
    }
}
