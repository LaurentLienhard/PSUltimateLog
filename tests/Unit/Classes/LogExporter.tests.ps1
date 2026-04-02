using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'LogExporter' -Tag 'Unit' {

    Context 'Abstract interface' {

        It 'Export throws NotImplementedException' {
            $exporter = [LogExporter]::new()
            $record   = [LogRecord]::new('msg', [OtelSeverity]::INFO)
            { $exporter.Export(@($record)) } | Should -Throw
        }

        It 'Flush throws NotImplementedException' {
            $exporter = [LogExporter]::new()
            { $exporter.Flush() } | Should -Throw
        }

        It 'Shutdown throws NotImplementedException' {
            $exporter = [LogExporter]::new()
            { $exporter.Shutdown() } | Should -Throw
        }

        It 'exception message includes the class name' {
            $exporter = [LogExporter]::new()
            try
            {
                $exporter.Export(@())
            }
            catch
            {
                $_.Exception.Message | Should -Match 'LogExporter'
            }
        }
    }
}
