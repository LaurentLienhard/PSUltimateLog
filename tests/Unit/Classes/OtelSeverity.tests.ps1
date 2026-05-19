BeforeAll {
    $projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
    if (-not $ProjectName) {
        $ProjectName = (Get-ChildItem -Path "$projectPath\*\*.psd1" |
            Where-Object { $_.FullName -notmatch '(output|RequiredModules)' } |
            Select-Object -First 1).BaseName
    }
    $script:projectName = $ProjectName
    if (-not (Get-Module -Name $script:projectName -ErrorAction SilentlyContinue)) {
        $manifest = Get-ChildItem -Path "$projectPath" -Filter "$script:projectName.psd1" -Recurse |
            Where-Object { $_.FullName -notmatch '(output|RequiredModules)' } |
            Select-Object -First 1
        Import-Module -Name $manifest.FullName -Force -ErrorAction Stop
    }
}

Describe 'OtelSeverity' {

    Context 'Static constants' {

        It 'TRACE equals 1' {
            InModuleScope $script:projectName {
                [OtelSeverity]::TRACE | Should -Be 1
            }
        }

        It 'DEBUG equals 5' {
            InModuleScope $script:projectName {
                [OtelSeverity]::DEBUG | Should -Be 5
            }
        }

        It 'INFO equals 9' {
            InModuleScope $script:projectName {
                [OtelSeverity]::INFO | Should -Be 9
            }
        }

        It 'WARN equals 13' {
            InModuleScope $script:projectName {
                [OtelSeverity]::WARN | Should -Be 13
            }
        }

        It 'ERROR equals 17' {
            InModuleScope $script:projectName {
                [OtelSeverity]::ERROR | Should -Be 17
            }
        }

        It 'FATAL equals 21' {
            InModuleScope $script:projectName {
                [OtelSeverity]::FATAL | Should -Be 21
            }
        }
    }

    Context 'GetText() — boundary and representative values' {

        It 'returns TRACE for severity number 1' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(1) | Should -Be 'TRACE'
            }
        }

        It 'returns DEBUG for severity number 5' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(5) | Should -Be 'DEBUG'
            }
        }

        It 'returns DEBUG for intermediate value 6' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(6) | Should -Be 'DEBUG'
            }
        }

        It 'returns INFO for severity number 9' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(9) | Should -Be 'INFO'
            }
        }

        It 'returns WARN for severity number 13' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(13) | Should -Be 'WARN'
            }
        }

        It 'returns ERROR for severity number 17' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(17) | Should -Be 'ERROR'
            }
        }

        It 'returns FATAL for severity number 21' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(21) | Should -Be 'FATAL'
            }
        }

        It 'returns UNSPECIFIED for 0' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(0) | Should -Be 'UNSPECIFIED'
            }
        }

        It 'returns UNSPECIFIED for 25' {
            InModuleScope $script:projectName {
                [OtelSeverity]::GetText(25) | Should -Be 'UNSPECIFIED'
            }
        }
    }

    Context 'IsValid()' {

        It 'returns true for 1 (lower bound)' {
            InModuleScope $script:projectName {
                [OtelSeverity]::IsValid(1) | Should -BeTrue
            }
        }

        It 'returns true for 9 (mid range)' {
            InModuleScope $script:projectName {
                [OtelSeverity]::IsValid(9) | Should -BeTrue
            }
        }

        It 'returns true for 24 (upper bound)' {
            InModuleScope $script:projectName {
                [OtelSeverity]::IsValid(24) | Should -BeTrue
            }
        }

        It 'returns false for 0 (below range)' {
            InModuleScope $script:projectName {
                [OtelSeverity]::IsValid(0) | Should -BeFalse
            }
        }

        It 'returns false for 25 (above range)' {
            InModuleScope $script:projectName {
                [OtelSeverity]::IsValid(25) | Should -BeFalse
            }
        }
    }
}
