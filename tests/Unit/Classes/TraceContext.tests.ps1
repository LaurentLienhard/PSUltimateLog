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

Describe 'TraceContext' {

    Context 'Default constructor' {

        It 'generates a TraceId matching ^[0-9a-f]{32}$' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $ctx.TraceId | Should -Match '^[0-9a-f]{32}$'
            }
        }

        It 'generates a SpanId matching ^[0-9a-f]{16}$' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $ctx.SpanId | Should -Match '^[0-9a-f]{16}$'
            }
        }

        It 'sets Flags to 1' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $ctx.Flags | Should -Be 1
            }
        }

        It 'produces unique TraceIds across two distinct instances' {
            InModuleScope $script:projectName {
                $ctx1 = [TraceContext]::new()
                $ctx2 = [TraceContext]::new()
                $ctx1.TraceId | Should -Not -Be $ctx2.TraceId
            }
        }
    }

    Context 'Traceparent constructor' {

        BeforeAll {
            $script:validTraceparent = '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        }

        It 'parses TraceId correctly' {
            InModuleScope $script:projectName -Parameters @{ tp = $script:validTraceparent } {
                param($tp)
                $ctx = [TraceContext]::new($tp)
                $ctx.TraceId | Should -Be '4bf92f3577b34da6a3ce929d0e0e4736'
            }
        }

        It 'parses SpanId correctly' {
            InModuleScope $script:projectName -Parameters @{ tp = $script:validTraceparent } {
                param($tp)
                $ctx = [TraceContext]::new($tp)
                $ctx.SpanId | Should -Be '00f067aa0ba902b7'
            }
        }

        It 'parses Flags correctly (hex 01 = int 1)' {
            InModuleScope $script:projectName -Parameters @{ tp = $script:validTraceparent } {
                param($tp)
                $ctx = [TraceContext]::new($tp)
                $ctx.Flags | Should -Be 1
            }
        }

        It 'throws ArgumentException for null or empty string' {
            InModuleScope $script:projectName {
                { [TraceContext]::new('') } | Should -Throw -ExceptionType ([System.ArgumentException])
            }
        }

        It 'throws FormatException for a malformed traceparent string' {
            InModuleScope $script:projectName {
                { [TraceContext]::new('not-a-valid-traceparent') } | Should -Throw -ExceptionType ([System.FormatException])
            }
        }
    }

    Context 'ToTraceparent()' {

        It 'returns the correct W3C traceparent format' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
                $ctx.ToTraceparent() | Should -Be '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
            }
        }
    }

    Context 'IsValid()' {

        It 'returns true for a freshly constructed instance' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $ctx.IsValid() | Should -BeTrue
            }
        }

        It 'returns false when TraceId is manually set to a bad value' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $ctx.TraceId = 'not-valid'
                $ctx.IsValid() | Should -BeFalse
            }
        }
    }
}
