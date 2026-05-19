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

Describe 'FileExporter' {

    Context 'Fixed-path constructor' {
        It 'Export creates the file at the given path' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $path = Join-Path $TestDrive 'test.jsonl'
                $exp  = [FileExporter]::new($path)
                $exp.Export(@([LogRecord]::new('msg', [OtelSeverity]::INFO)))
                Test-Path $path | Should -BeTrue
            }
        }

        It 'Export writes valid JSON lines' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $path = Join-Path $TestDrive 'test2.jsonl'
                $exp  = [FileExporter]::new($path)
                $exp.Export(@([LogRecord]::new('hello world', [OtelSeverity]::WARN)))
                $line = Get-Content -Path $path -Raw
                { $line | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        It 'multiple Export calls append records' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $path = Join-Path $TestDrive 'append.jsonl'
                $exp  = [FileExporter]::new($path)
                $exp.Export(@([LogRecord]::new('first', [OtelSeverity]::INFO)))
                $exp.Export(@([LogRecord]::new('second', [OtelSeverity]::DEBUG)))
                $lines = Get-Content -Path $path
                $lines.Count | Should -Be 2
            }
        }
    }

    Context 'Date-rotation constructor' {
        It 'Export creates a file whose name matches prefix-yyyy-MM-dd.jsonl' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $dir    = Join-Path $TestDrive 'rotated'
                $prefix = 'myapp'
                $exp    = [FileExporter]::new($dir, $prefix)
                $exp.Export(@([LogRecord]::new('rotated msg', [OtelSeverity]::ERROR)))
                $dateStr = [System.DateTime]::UtcNow.ToString('yyyy-MM-dd')
                $expected = Join-Path $dir "$prefix-$dateStr.jsonl"
                Test-Path $expected | Should -BeTrue
            }
        }
    }

    Context 'Intermediate directory creation' {
        It 'Export creates intermediate directories if they do not exist' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $path = Join-Path $TestDrive 'subdir' 'nested' 'out.jsonl'
                $exp  = [FileExporter]::new($path)
                $exp.Export(@([LogRecord]::new('nested', [OtelSeverity]::TRACE)))
                Test-Path $path | Should -BeTrue
            }
        }
    }

    Context 'After Shutdown' {
        It 'Export throws InvalidOperationException' {
            InModuleScope $script:projectName -Parameters @{ TestDrive = $TestDrive } {
                param($TestDrive)
                $path = Join-Path $TestDrive 'shutdown.jsonl'
                $exp  = [FileExporter]::new($path)
                $exp.Shutdown()
                { $exp.Export(@([LogRecord]::new('msg', [OtelSeverity]::INFO))) } |
                    Should -Throw -ExceptionType ([System.InvalidOperationException])
            }
        }
    }
}
