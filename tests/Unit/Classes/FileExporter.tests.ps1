using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'FileExporter' -Tag 'Unit' {

    Context 'Constructor' {

        It 'stores the Path property' {
            $exp = [FileExporter]::new('C:\logs\out.jsonl')
            $exp.Path | Should -Be 'C:\logs\out.jsonl'
        }

        It 'IsShutdown is false after construction' {
            [FileExporter]::new('out.jsonl').IsShutdown | Should -BeFalse
        }

        It 'inherits from LogExporter' {
            [FileExporter]::new('out.jsonl') -is [LogExporter] | Should -BeTrue
        }

        It 'throws on null path' {
            { [FileExporter]::new($null) } | Should -Throw
        }

        It 'throws on empty path' {
            { [FileExporter]::new('') } | Should -Throw
        }

        It 'throws on whitespace path' {
            { [FileExporter]::new('   ') } | Should -Throw
        }
    }

    Context 'Export' {

        It 'writes a JSON line to the file' {
            $path   = Join-Path $TestDrive 'test.jsonl'
            $exp    = [FileExporter]::new($path)
            $record = [LogRecord]::new('hello file', [OtelSeverity]::INFO)

            $exp.Export(@($record))

            $path | Should -Exist
            $lines = @(Get-Content -Path $path)
            $lines.Count | Should -Be 1
            { $lines[0] | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'appends multiple records as separate lines' {
            $path = Join-Path $TestDrive 'multi.jsonl'
            $exp  = [FileExporter]::new($path)
            $records = @(
                [LogRecord]::new('line 1', [OtelSeverity]::DEBUG)
                [LogRecord]::new('line 2', [OtelSeverity]::WARN)
                [LogRecord]::new('line 3', [OtelSeverity]::ERROR)
            )

            $exp.Export($records)

            (Get-Content -Path $path).Count | Should -Be 3
        }

        It 'appends to an existing file on subsequent exports' {
            $path = Join-Path $TestDrive 'append.jsonl'
            $exp  = [FileExporter]::new($path)

            $exp.Export(@([LogRecord]::new('first', [OtelSeverity]::INFO)))
            $exp.Export(@([LogRecord]::new('second', [OtelSeverity]::INFO)))

            (Get-Content -Path $path).Count | Should -Be 2
        }

        It 'each line contains valid JSON with severityText' {
            $path = Join-Path $TestDrive 'valid.jsonl'
            $exp  = [FileExporter]::new($path)
            $exp.Export(@([LogRecord]::new('test', [OtelSeverity]::WARN)))

            $line = Get-Content -Path $path -Raw
            ($line | ConvertFrom-Json).severityText | Should -Be 'WARN'
        }

        It 'does nothing for an empty records array' {
            $path = Join-Path $TestDrive 'empty.jsonl'
            $exp  = [FileExporter]::new($path)
            $exp.Export(@())
            $path | Should -Not -Exist
        }

        It 'does nothing for a null records array' {
            $path = Join-Path $TestDrive 'null.jsonl'
            $exp  = [FileExporter]::new($path)
            $exp.Export($null)
            $path | Should -Not -Exist
        }

        It 'throws after Shutdown' {
            $path   = Join-Path $TestDrive 'shutdown.jsonl'
            $exp    = [FileExporter]::new($path)
            $record = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            $exp.Shutdown()
            { $exp.Export(@($record)) } | Should -Throw
        }
    }

    Context 'Flush' {

        It 'does not throw' {
            $exp = [FileExporter]::new((Join-Path $TestDrive 'flush.jsonl'))
            { $exp.Flush() } | Should -Not -Throw
        }
    }

    Context 'Shutdown' {

        It 'sets IsShutdown to true' {
            $exp = [FileExporter]::new('out.jsonl')
            $exp.Shutdown()
            $exp.IsShutdown | Should -BeTrue
        }

        It 'does not throw on repeated calls' {
            $exp = [FileExporter]::new('out.jsonl')
            $exp.Shutdown()
            { $exp.Shutdown() } | Should -Not -Throw
        }
    }
}
