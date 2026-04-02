BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'LogRecord' -Tag 'Unit' {

    Context 'Constructor - body and severity' {

        It 'sets Body correctly' {
            $lr = [LogRecord]::new('hello world', [OtelSeverity]::INFO)
            $lr.Body | Should -Be 'hello world'
        }

        It 'sets SeverityNumber to the enum int value' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::WARN)
            $lr.SeverityNumber | Should -Be 13
        }

        It 'sets SeverityText to the enum name' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::ERROR)
            $lr.SeverityText | Should -Be 'ERROR'
        }

        It 'sets TimeUnixNano to a non-empty numeric string' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.TimeUnixNano | Should -Not -BeNullOrEmpty
            { [long]$lr.TimeUnixNano } | Should -Not -Throw
        }

        It 'sets ObservedTimeUnixNano equal to TimeUnixNano' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.ObservedTimeUnixNano | Should -Be $lr.TimeUnixNano
        }

        It 'sets TraceId to empty string' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::DEBUG)
            $lr.TraceId | Should -Be ''
        }

        It 'sets SpanId to empty string' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::DEBUG)
            $lr.SpanId | Should -Be ''
        }

        It 'sets Flags to 0' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::DEBUG)
            $lr.Flags | Should -Be 0
        }

        It 'treats null body as empty string' {
            $lr = [LogRecord]::new($null, [OtelSeverity]::INFO)
            $lr.Body | Should -Be ''
        }

        It 'works for each severity level' -ForEach @(
            @{ Severity = [OtelSeverity]::TRACE; Number = 1;  Text = 'TRACE' }
            @{ Severity = [OtelSeverity]::DEBUG; Number = 5;  Text = 'DEBUG' }
            @{ Severity = [OtelSeverity]::INFO;  Number = 9;  Text = 'INFO'  }
            @{ Severity = [OtelSeverity]::WARN;  Number = 13; Text = 'WARN'  }
            @{ Severity = [OtelSeverity]::ERROR; Number = 17; Text = 'ERROR' }
            @{ Severity = [OtelSeverity]::FATAL; Number = 21; Text = 'FATAL' }
        ) {
            $lr = [LogRecord]::new('msg', $Severity)
            $lr.SeverityNumber | Should -Be $Number
            $lr.SeverityText   | Should -Be $Text
        }
    }

    Context 'Constructor - body, severity, and TraceContext' {

        It 'copies TraceId from the context' {
            $ctx = [TraceContext]::new()
            $lr  = [LogRecord]::new('msg', [OtelSeverity]::INFO, $ctx)
            $lr.TraceId | Should -Be $ctx.TraceId
        }

        It 'copies SpanId from the context' {
            $ctx = [TraceContext]::new()
            $lr  = [LogRecord]::new('msg', [OtelSeverity]::INFO, $ctx)
            $lr.SpanId | Should -Be $ctx.SpanId
        }

        It 'copies Flags from the context' {
            $ctx = [TraceContext]::new('00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
            $lr  = [LogRecord]::new('msg', [OtelSeverity]::INFO, $ctx)
            $lr.Flags | Should -Be 1
        }

        It 'throws when Context is null' {
            { [LogRecord]::new('msg', [OtelSeverity]::INFO, $null) } | Should -Throw
        }
    }

    Context 'SetAttribute / GetAttribute / HasAttribute' {

        It 'stores and retrieves a string attribute' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.SetAttribute('env', 'production')
            $lr.GetAttribute('env') | Should -Be 'production'
        }

        It 'stores and retrieves an integer attribute' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.SetAttribute('http.status_code', 200)
            $lr.GetAttribute('http.status_code') | Should -Be 200
        }

        It 'overwrites an existing attribute' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.SetAttribute('k', 'v1')
            $lr.SetAttribute('k', 'v2')
            $lr.GetAttribute('k') | Should -Be 'v2'
        }

        It 'HasAttribute returns true for an existing key' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.SetAttribute('present', 1)
            $lr.HasAttribute('present') | Should -BeTrue
        }

        It 'HasAttribute returns false for a missing key' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.HasAttribute('absent') | Should -BeFalse
        }

        It 'GetAttribute returns null for a missing key' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.GetAttribute('missing') | Should -BeNull
        }

        It 'SetAttribute throws on empty key' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            { $lr.SetAttribute('', 'v') } | Should -Throw
        }
    }

    Context 'ToOtlp' {

        It 'contains timeUnixNano' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $otlp = $lr.ToOtlp()
            $otlp.timeUnixNano | Should -Not -BeNullOrEmpty
        }

        It 'contains observedTimeUnixNano' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $otlp = $lr.ToOtlp()
            $otlp.observedTimeUnixNano | Should -Not -BeNullOrEmpty
        }

        It 'sets severityNumber correctly' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::FATAL)
            $otlp = $lr.ToOtlp()
            $otlp.severityNumber | Should -Be 21
        }

        It 'sets severityText correctly' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::FATAL)
            $otlp = $lr.ToOtlp()
            $otlp.severityText | Should -Be 'FATAL'
        }

        It 'wraps body in stringValue' {
            $lr   = [LogRecord]::new('test body', [OtelSeverity]::INFO)
            $otlp = $lr.ToOtlp()
            $otlp.body.stringValue | Should -Be 'test body'
        }

        It 'includes traceId and spanId' {
            $ctx  = [TraceContext]::new()
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::INFO, $ctx)
            $otlp = $lr.ToOtlp()
            $otlp.traceId | Should -Be $ctx.TraceId
            $otlp.spanId  | Should -Be $ctx.SpanId
        }

        It 'includes droppedAttributesCount as 0' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $otlp = $lr.ToOtlp()
            $otlp.droppedAttributesCount | Should -Be 0
        }

        It 'includes set attributes in the output' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.SetAttribute('http.method', 'GET')
            $otlp = $lr.ToOtlp()
            $attr = $otlp.attributes | Where-Object { $_.key -eq 'http.method' }
            $attr.value.stringValue | Should -Be 'GET'
        }
    }

    Context 'ToOtlpJson' {

        It 'returns a non-empty string' {
            $lr = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $lr.ToOtlpJson() | Should -Not -BeNullOrEmpty
        }

        It 'returns valid JSON' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $json = $lr.ToOtlpJson()
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON contains severityText' {
            $lr   = [LogRecord]::new('msg', [OtelSeverity]::WARN)
            $data = $lr.ToOtlpJson() | ConvertFrom-Json
            $data.severityText | Should -Be 'WARN'
        }
    }

    Context 'GetCurrentTimeUnixNano' {

        It 'returns a positive numeric string' {
            $nano = [LogRecord]::GetCurrentTimeUnixNano()
            $nano | Should -Not -BeNullOrEmpty
            [long]$nano | Should -BeGreaterThan 0
        }

        It 'returns a value representing a recent time (after 2020-01-01)' {
            # 2020-01-01 in nanoseconds since Unix epoch
            $floor = 1577836800000000000L
            [long][LogRecord]::GetCurrentTimeUnixNano() | Should -BeGreaterThan $floor
        }

        It 'returns increasing values on successive calls' {
            $t1 = [long][LogRecord]::GetCurrentTimeUnixNano()
            Start-Sleep -Milliseconds 10
            $t2 = [long][LogRecord]::GetCurrentTimeUnixNano()
            $t2 | Should -BeGreaterThan $t1
        }
    }
}
