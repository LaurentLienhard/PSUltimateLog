BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'ConsoleExporter' -Tag 'Unit' {

    Context 'Constructor' {

        It 'creates an instance successfully' {
            { [ConsoleExporter]::new() } | Should -Not -Throw
        }

        It 'IsShutdown is false after construction' {
            [ConsoleExporter]::new().IsShutdown | Should -BeFalse
        }

        It 'inherits from LogExporter' {
            [ConsoleExporter]::new() -is [LogExporter] | Should -BeTrue
        }
    }

    Context 'Export' {

        It 'does not throw for a valid record' {
            $exp    = [ConsoleExporter]::new()
            $record = [LogRecord]::new('hello', [OtelSeverity]::INFO)
            { $exp.Export(@($record)) } | Should -Not -Throw
        }

        It 'does not throw for an empty array' {
            $exp = [ConsoleExporter]::new()
            { $exp.Export(@()) } | Should -Not -Throw
        }

        It 'does not throw for a null array' {
            $exp = [ConsoleExporter]::new()
            { $exp.Export($null) } | Should -Not -Throw
        }

        It 'does not throw for multiple records' {
            $exp = [ConsoleExporter]::new()
            $records = @(
                [LogRecord]::new('first',  [OtelSeverity]::DEBUG)
                [LogRecord]::new('second', [OtelSeverity]::WARN)
                [LogRecord]::new('third',  [OtelSeverity]::ERROR)
            )
            { $exp.Export($records) } | Should -Not -Throw
        }

        It 'throws after Shutdown' {
            $exp    = [ConsoleExporter]::new()
            $record = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $exp.Shutdown()
            { $exp.Export(@($record)) } | Should -Throw
        }
    }

    Context 'Flush' {

        It 'does not throw' {
            { [ConsoleExporter]::new().Flush() } | Should -Not -Throw
        }
    }

    Context 'Shutdown' {

        It 'sets IsShutdown to true' {
            $exp = [ConsoleExporter]::new()
            $exp.Shutdown()
            $exp.IsShutdown | Should -BeTrue
        }

        It 'does not throw on repeated calls' {
            $exp = [ConsoleExporter]::new()
            $exp.Shutdown()
            { $exp.Shutdown() } | Should -Not -Throw
        }
    }

    Context 'FormatTimestamp' {

        It 'returns a non-empty string' {
            $nano = [LogRecord]::GetCurrentTimeUnixNano()
            [ConsoleExporter]::FormatTimestamp($nano) | Should -Not -BeNullOrEmpty
        }

        It 'returns a string matching ISO-8601 UTC format' {
            $nano = [LogRecord]::GetCurrentTimeUnixNano()
            [ConsoleExporter]::FormatTimestamp($nano) | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$'
        }

        It 'returns a fallback timestamp for invalid input' {
            [ConsoleExporter]::FormatTimestamp('not-a-number') | Should -Match '^\d{4}-\d{2}-\d{2}T'
        }
    }
}
