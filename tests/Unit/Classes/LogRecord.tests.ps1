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

Describe 'LogRecord' {

    Context 'Constructor(body, severity) — no context' {

        It 'sets SeverityNumber correctly for INFO (9)' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('test message', 9)
                $record.SeverityNumber | Should -Be 9
            }
        }

        It 'sets SeverityText to INFO for severity number 9' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('test message', 9)
                $record.SeverityText | Should -Be 'INFO'
            }
        }

        It 'sets Body to the provided value' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('my log body', 9)
                $record.Body | Should -Be 'my log body'
            }
        }

        It 'sets TimeUnixNano to a non-empty numeric string' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.TimeUnixNano | Should -Not -BeNullOrEmpty
                $record.TimeUnixNano | Should -Match '^\d+$'
            }
        }

        It 'sets TraceId to empty string when no context is provided' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.TraceId | Should -Be ''
            }
        }

        It 'sets SpanId to empty string when no context is provided' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.SpanId | Should -Be ''
            }
        }

        It 'sets Flags to 0 when no context is provided' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.Flags | Should -Be 0
            }
        }

        It 'sets DroppedAttributesCount to 0 after construction' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.DroppedAttributesCount | Should -Be 0
            }
        }
    }

    Context 'Constructor(body, severity, context) — with TraceContext' {

        It 'copies TraceId from the provided context' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $record = [LogRecord]::new('msg', 9, $ctx)
                $record.TraceId | Should -Be $ctx.TraceId
            }
        }

        It 'copies SpanId from the provided context' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $record = [LogRecord]::new('msg', 9, $ctx)
                $record.SpanId | Should -Be $ctx.SpanId
            }
        }

        It 'copies Flags from the provided context' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()
                $record = [LogRecord]::new('msg', 9, $ctx)
                $record.Flags | Should -Be $ctx.Flags
            }
        }
    }

    Context 'SetAttribute()' {

        It 'string attribute is present in ToOtlpJson() output' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.SetAttribute('app.version', '1.2.3')
                $json = $record.ToOtlpJson()
                $parsed = $json | ConvertFrom-Json
                $attr = $parsed.attributes | Where-Object { $_.key -eq 'app.version' }
                $attr | Should -Not -BeNullOrEmpty
                $attr.value.stringValue | Should -Be '1.2.3'
            }
        }

        It 'integer attribute produces intValue in ToOtlpJson() output' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.SetAttribute('retry.count', [int]3)
                $json = $record.ToOtlpJson()
                $parsed = $json | ConvertFrom-Json
                $attr = $parsed.attributes | Where-Object { $_.key -eq 'retry.count' }
                $attr | Should -Not -BeNullOrEmpty
                $attr.value.intValue | Should -Be 3
            }
        }

        It 'updating an existing key results in no duplicate entries' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('msg', 9)
                $record.SetAttribute('env', 'staging')
                $record.SetAttribute('env', 'production')
                $json = $record.ToOtlpJson()
                $parsed = $json | ConvertFrom-Json
                $attrs = @($parsed.attributes | Where-Object { $_.key -eq 'env' })
                $attrs.Count | Should -Be 1
                $attrs[0].value.stringValue | Should -Be 'production'
            }
        }
    }

    Context 'ToOtlpJson()' {

        It 'returns valid JSON without throwing' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('hello', 9)
                { $record.ToOtlpJson() | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        It 'result contains severityText at the root level' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('hello', 9)
                $parsed = $record.ToOtlpJson() | ConvertFrom-Json
                $parsed.severityText | Should -Be 'INFO'
            }
        }

        It 'result contains body.stringValue with the log body' {
            InModuleScope $script:projectName {
                $record = [LogRecord]::new('the body text', 9)
                $parsed = $record.ToOtlpJson() | ConvertFrom-Json
                $parsed.body.stringValue | Should -Be 'the body text'
            }
        }

        It 'flags is integer 1 when context with Flags=1 is provided' {
            InModuleScope $script:projectName {
                $ctx = [TraceContext]::new()   # default constructor sets Flags = 1
                $record = [LogRecord]::new('msg', 9, $ctx)
                $parsed = $record.ToOtlpJson() | ConvertFrom-Json
                $parsed.flags | Should -Be 1
            }
        }
    }
}
