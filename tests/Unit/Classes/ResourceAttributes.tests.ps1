using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'ResourceAttributes' -Tag 'Unit' {

    Context 'Default constructor' {

        It 'populates host.name' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('host.name') | Should -BeTrue
            $ra.GetAttribute('host.name') | Should -Not -BeNullOrEmpty
        }

        It 'populates os.type' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('os.type') | Should -BeTrue
            $ra.GetAttribute('os.type') | Should -BeIn @('windows', 'linux', 'darwin')
        }

        It 'populates process.pid with a positive integer' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('process.pid') | Should -BeTrue
            $ra.GetAttribute('process.pid') | Should -BeGreaterThan 0
        }

        It 'populates process.runtime.name as PowerShell' {
            $ra = [ResourceAttributes]::new()
            $ra.GetAttribute('process.runtime.name') | Should -Be 'PowerShell'
        }

        It 'populates process.runtime.version' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('process.runtime.version') | Should -BeTrue
            $ra.GetAttribute('process.runtime.version') | Should -Not -BeNullOrEmpty
        }

        It 'does not set service.name' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('service.name') | Should -BeFalse
        }
    }

    Context 'Constructor with ServiceName' {

        It 'sets service.name to the provided value' {
            $ra = [ResourceAttributes]::new('my-service')
            $ra.GetAttribute('service.name') | Should -Be 'my-service'
        }

        It 'still populates default attributes' {
            $ra = [ResourceAttributes]::new('my-service')
            $ra.HasAttribute('host.name')    | Should -BeTrue
            $ra.HasAttribute('os.type')      | Should -BeTrue
            $ra.HasAttribute('process.pid')  | Should -BeTrue
        }
    }

    Context 'SetAttribute' {

        It 'adds a new attribute' {
            $ra = [ResourceAttributes]::new()
            $ra.SetAttribute('service.version', '1.2.3')
            $ra.GetAttribute('service.version') | Should -Be '1.2.3'
        }

        It 'overwrites an existing attribute' {
            $ra = [ResourceAttributes]::new('original')
            $ra.SetAttribute('service.name', 'updated')
            $ra.GetAttribute('service.name') | Should -Be 'updated'
        }

        It 'throws on null key' {
            $ra = [ResourceAttributes]::new()
            { $ra.SetAttribute($null, 'value') } | Should -Throw
        }

        It 'throws on empty key' {
            $ra = [ResourceAttributes]::new()
            { $ra.SetAttribute('', 'value') } | Should -Throw
        }
    }

    Context 'GetAttribute' {

        It 'returns null for a missing key' {
            $ra = [ResourceAttributes]::new()
            $ra.GetAttribute('nonexistent.key') | Should -BeNull
        }

        It 'returns the correct value for an existing key' {
            $ra = [ResourceAttributes]::new()
            $ra.SetAttribute('custom.key', 42)
            $ra.GetAttribute('custom.key') | Should -Be 42
        }
    }

    Context 'HasAttribute' {

        It 'returns true for an existing attribute' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('host.name') | Should -BeTrue
        }

        It 'returns false for a missing attribute' {
            $ra = [ResourceAttributes]::new()
            $ra.HasAttribute('not.there') | Should -BeFalse
        }
    }

    Context 'RemoveAttribute' {

        It 'removes an existing attribute' {
            $ra = [ResourceAttributes]::new('svc')
            $ra.RemoveAttribute('service.name')
            $ra.HasAttribute('service.name') | Should -BeFalse
        }

        It 'does not throw when removing a non-existent key' {
            $ra = [ResourceAttributes]::new()
            { $ra.RemoveAttribute('ghost.key') } | Should -Not -Throw
        }
    }

    Context 'GetKeys' {

        It 'returns all attribute keys' {
            $ra = [ResourceAttributes]::new()
            $keys = $ra.GetKeys()
            $keys | Should -Contain 'host.name'
            $keys | Should -Contain 'os.type'
            $keys | Should -Contain 'process.pid'
        }

        It 'reflects added and removed attributes' {
            $ra = [ResourceAttributes]::new()
            $ra.SetAttribute('custom.x', 'val')
            $ra.GetKeys() | Should -Contain 'custom.x'
            $ra.RemoveAttribute('custom.x')
            $ra.GetKeys() | Should -Not -Contain 'custom.x'
        }
    }

    Context 'ToOtlpAttributes' {

        It 'returns an array of objects with key and value properties' {
            $ra = [ResourceAttributes]::new('svc')
            $otlp = $ra.ToOtlpAttributes()
            $otlp | Should -Not -BeNullOrEmpty
            $otlp[0].key   | Should -Not -BeNullOrEmpty
            $otlp[0].value | Should -Not -BeNullOrEmpty
        }

        It 'wraps string values in stringValue' {
            $ra = [ResourceAttributes]::new()
            $ra.SetAttribute('only.attr', 'hello')
            # remove defaults to isolate
            foreach ($k in @('host.name', 'os.type', 'process.pid', 'process.runtime.name', 'process.runtime.version'))
            {
                $ra.RemoveAttribute($k)
            }
            $otlp = $ra.ToOtlpAttributes()
            $otlp[0].value.stringValue | Should -Be 'hello'
        }

        It 'wraps integer values in intValue' {
            $ra = [ResourceAttributes]::new()
            foreach ($k in @('host.name', 'os.type', 'process.pid', 'process.runtime.name', 'process.runtime.version'))
            {
                $ra.RemoveAttribute($k)
            }
            $ra.SetAttribute('int.attr', [int]99)
            $otlp = $ra.ToOtlpAttributes()
            $otlp[0].value.intValue | Should -Be 99
        }

        It 'wraps boolean values in boolValue' {
            $ra = [ResourceAttributes]::new()
            foreach ($k in @('host.name', 'os.type', 'process.pid', 'process.runtime.name', 'process.runtime.version'))
            {
                $ra.RemoveAttribute($k)
            }
            $ra.SetAttribute('bool.attr', $true)
            $otlp = $ra.ToOtlpAttributes()
            $otlp[0].value.boolValue | Should -BeTrue
        }
    }

    Context 'DetectOsType' {

        It 'returns a non-empty string' {
            [ResourceAttributes]::DetectOsType() | Should -Not -BeNullOrEmpty
        }

        It 'returns a known OS type' {
            [ResourceAttributes]::DetectOsType() | Should -BeIn @('windows', 'linux', 'darwin')
        }
    }
}
