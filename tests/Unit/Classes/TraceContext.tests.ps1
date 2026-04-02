BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'TraceContext' -Tag 'Unit' {

    Context 'Default constructor' {

        It 'generates a 32-char lowercase hex TraceId' {
            $ctx = [TraceContext]::new()
            $ctx.TraceId | Should -Match '^[0-9a-f]{32}$'
        }

        It 'generates a 16-char lowercase hex SpanId' {
            $ctx = [TraceContext]::new()
            $ctx.SpanId | Should -Match '^[0-9a-f]{16}$'
        }

        It 'sets TraceFlags to 1 (sampled)' {
            $ctx = [TraceContext]::new()
            $ctx.TraceFlags | Should -Be 1
        }

        It 'sets TraceState to empty string' {
            $ctx = [TraceContext]::new()
            $ctx.TraceState | Should -Be ''
        }

        It 'generates unique TraceId on each call' {
            $ctx1 = [TraceContext]::new()
            $ctx2 = [TraceContext]::new()
            $ctx1.TraceId | Should -Not -Be $ctx2.TraceId
        }

        It 'generates unique SpanId on each call' {
            $ctx1 = [TraceContext]::new()
            $ctx2 = [TraceContext]::new()
            $ctx1.SpanId | Should -Not -Be $ctx2.SpanId
        }
    }

    Context 'Constructor from traceparent' {

        It 'parses TraceId correctly' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.TraceId | Should -Be '4bf92f3577b34da6a3ce929d0e0e4736'
        }

        It 'parses SpanId correctly' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.SpanId | Should -Be '00f067aa0ba902b7'
        }

        It 'parses TraceFlags correctly' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.TraceFlags | Should -Be 1
        }

        It 'sets TraceState to empty string when not provided' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.TraceState | Should -Be ''
        }
    }

    Context 'Constructor from traceparent and tracestate' {

        It 'parses traceparent and stores tracestate' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01', 'vendor=value')
            $ctx.TraceId    | Should -Be '4bf92f3577b34da6a3ce929d0e0e4736'
            $ctx.TraceState | Should -Be 'vendor=value'
        }
    }

    Context 'GenerateTraceId' {

        It 'returns a 32-char lowercase hex string' {
            [TraceContext]::GenerateTraceId() | Should -Match '^[0-9a-f]{32}$'
        }
    }

    Context 'GenerateSpanId' {

        It 'returns a 16-char lowercase hex string' {
            [TraceContext]::GenerateSpanId() | Should -Match '^[0-9a-f]{16}$'
        }
    }

    Context 'ParseTraceparent - invalid input' {

        It 'throws on null input' {
            { [TraceContext]::ParseTraceparent($null) } | Should -Throw
        }

        It 'throws on empty string' {
            { [TraceContext]::ParseTraceparent('') } | Should -Throw
        }

        It 'throws when fewer than 4 parts' {
            { [TraceContext]::ParseTraceparent('00-abc-def') } | Should -Throw
        }

        It 'throws on unsupported version' {
            { [TraceContext]::ParseTraceparent('ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01') } | Should -Throw
        }

        It 'throws on all-zero trace-id' {
            { [TraceContext]::ParseTraceparent('00-00000000000000000000000000000000-00f067aa0ba902b7-01') } | Should -Throw
        }

        It 'throws on trace-id with wrong length' {
            { [TraceContext]::ParseTraceparent('00-abc123-00f067aa0ba902b7-01') } | Should -Throw
        }

        It 'throws on all-zero span-id' {
            { [TraceContext]::ParseTraceparent('00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01') } | Should -Throw
        }

        It 'throws on span-id with wrong length' {
            { [TraceContext]::ParseTraceparent('00-4bf92f3577b34da6a3ce929d0e0e4736-abc-01') } | Should -Throw
        }

        It 'throws on invalid trace-flags' {
            { [TraceContext]::ParseTraceparent('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-zz') } | Should -Throw
        }
    }

    Context 'ToTraceparent' {

        It 'returns the correct traceparent format' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.ToTraceparent() | Should -Be '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
        }

        It 'round-trips a generated context' {
            $ctx1 = [TraceContext]::new()
            $ctx2 = [TraceContext]::new($ctx1.ToTraceparent())
            $ctx2.TraceId | Should -Be $ctx1.TraceId
            $ctx2.SpanId  | Should -Be $ctx1.SpanId
        }
    }

    Context 'IsSampled' {

        It 'returns true when TraceFlags bit 0 is set' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $ctx.IsSampled() | Should -BeTrue
        }

        It 'returns false when TraceFlags bit 0 is not set' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00')
            $ctx.IsSampled() | Should -BeFalse
        }
    }
}
