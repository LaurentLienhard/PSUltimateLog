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

Describe 'ResourceAttributes' {

    Context 'Constructor auto-population' {

        It 'sets service.name to the provided value' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('my-service')
                $ra.GetAttribute('service.name') | Should -Be 'my-service'
            }
        }

        It 'auto-populates host.name (not null or empty)' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('host.name') | Should -Not -BeNullOrEmpty
            }
        }

        It 'auto-populates os.type (not null or empty)' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('os.type') | Should -Not -BeNullOrEmpty
            }
        }

        It 'auto-populates process.pid greater than 0' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('process.pid') | Should -BeGreaterThan 0
            }
        }

        It 'auto-populates process.runtime.name as PowerShell' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('process.runtime.name') | Should -Be 'PowerShell'
            }
        }

        It 'auto-populates process.runtime.version (not null or empty)' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('process.runtime.version') | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'HasAttribute()' {

        It 'returns true for service.name which was set by the constructor' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.HasAttribute('service.name') | Should -BeTrue
            }
        }

        It 'returns false for a key that does not exist' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.HasAttribute('no.such.key') | Should -BeFalse
            }
        }
    }

    Context 'GetAttribute()' {

        It 'returns the service name for service.name' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('hello-world')
                $ra.GetAttribute('service.name') | Should -Be 'hello-world'
            }
        }

        It 'returns null for a non-existent key' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.GetAttribute('does.not.exist') | Should -BeNullOrEmpty
            }
        }
    }

    Context 'SetAttribute()' {

        It 'adds a new key-value pair' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.SetAttribute('custom.key', 'custom-value')
                $ra.GetAttribute('custom.key') | Should -Be 'custom-value'
            }
        }

        It 'updates an existing key' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('original-name')
                $ra.SetAttribute('service.name', 'updated-name')
                $ra.GetAttribute('service.name') | Should -Be 'updated-name'
            }
        }
    }

    Context 'ToOtlpAttributes()' {

        It 'returns an array that contains an entry with key service.name and the correct stringValue' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('test-svc')
                $attrs = $ra.ToOtlpAttributes()
                $entry = $attrs | Where-Object { $_.key -eq 'service.name' }
                $entry | Should -Not -BeNullOrEmpty
                $entry.value.stringValue | Should -Be 'test-svc'
            }
        }

        It 'uses intValue for an integer attribute value' {
            InModuleScope $script:projectName {
                $ra = [ResourceAttributes]::new('svc')
                $ra.SetAttribute('custom.count', [int]42)
                $attrs = $ra.ToOtlpAttributes()
                $entry = $attrs | Where-Object { $_.key -eq 'custom.count' }
                $entry | Should -Not -BeNullOrEmpty
                $entry.value.intValue | Should -Be 42
            }
        }
    }
}
