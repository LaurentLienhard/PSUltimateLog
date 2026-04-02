using module PSUltimateLog

BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path

    if (-not $ProjectName)
    {
        $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
    }

    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}

Describe 'InstrumentationScope' -Tag 'Unit' {

    Context 'Constructor - name only' {

        It 'sets Name correctly' {
            $scope = [InstrumentationScope]::new('PSUltimateLog')
            $scope.Name | Should -Be 'PSUltimateLog'
        }

        It 'sets Version to empty string' {
            $scope = [InstrumentationScope]::new('PSUltimateLog')
            $scope.Version | Should -Be ''
        }

        It 'sets SchemaUrl to empty string' {
            $scope = [InstrumentationScope]::new('PSUltimateLog')
            $scope.SchemaUrl | Should -Be ''
        }

        It 'throws on null name' {
            { [InstrumentationScope]::new($null) } | Should -Throw
        }

        It 'throws on empty name' {
            { [InstrumentationScope]::new('') } | Should -Throw
        }

        It 'throws on whitespace-only name' {
            { [InstrumentationScope]::new('   ') } | Should -Throw
        }
    }

    Context 'Constructor - name and version' {

        It 'sets Name and Version correctly' {
            $scope = [InstrumentationScope]::new('PSUltimateLog', '1.2.3')
            $scope.Name    | Should -Be 'PSUltimateLog'
            $scope.Version | Should -Be '1.2.3'
        }

        It 'sets SchemaUrl to empty string' {
            $scope = [InstrumentationScope]::new('PSUltimateLog', '1.0.0')
            $scope.SchemaUrl | Should -Be ''
        }

        It 'throws on null name' {
            { [InstrumentationScope]::new($null, '1.0.0') } | Should -Throw
        }
    }

    Context 'Constructor - name, version, and schemaUrl' {

        It 'sets all three properties' {
            $scope = [InstrumentationScope]::new('PSUltimateLog', '1.0.0', 'https://opentelemetry.io/schemas/1.21.0')
            $scope.Name      | Should -Be 'PSUltimateLog'
            $scope.Version   | Should -Be '1.0.0'
            $scope.SchemaUrl | Should -Be 'https://opentelemetry.io/schemas/1.21.0'
        }

        It 'throws on null name' {
            { [InstrumentationScope]::new($null, '1.0.0', '') } | Should -Throw
        }
    }

    Context 'SetAttribute' {

        It 'adds a new attribute' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('custom.key', 'value')
            $scope.GetAttribute('custom.key') | Should -Be 'value'
        }

        It 'overwrites an existing attribute' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('k', 'first')
            $scope.SetAttribute('k', 'second')
            $scope.GetAttribute('k') | Should -Be 'second'
        }

        It 'throws on null key' {
            $scope = [InstrumentationScope]::new('lib')
            { $scope.SetAttribute($null, 'v') } | Should -Throw
        }

        It 'throws on empty key' {
            $scope = [InstrumentationScope]::new('lib')
            { $scope.SetAttribute('', 'v') } | Should -Throw
        }
    }

    Context 'GetAttribute' {

        It 'returns the value for an existing key' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('x', 99)
            $scope.GetAttribute('x') | Should -Be 99
        }

        It 'returns null for a missing key' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.GetAttribute('missing') | Should -BeNull
        }
    }

    Context 'HasAttribute' {

        It 'returns true when the attribute exists' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('present', 'yes')
            $scope.HasAttribute('present') | Should -BeTrue
        }

        It 'returns false when the attribute does not exist' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.HasAttribute('absent') | Should -BeFalse
        }
    }

    Context 'ToOtlp' {

        It 'includes the name field' {
            $scope = [InstrumentationScope]::new('PSUltimateLog')
            $otlp = $scope.ToOtlp()
            $otlp.name | Should -Be 'PSUltimateLog'
        }

        It 'includes the version field' {
            $scope = [InstrumentationScope]::new('PSUltimateLog', '2.0.0')
            $scope.ToOtlp().version | Should -Be '2.0.0'
        }

        It 'includes the schemaUrl field' {
            $scope = [InstrumentationScope]::new('lib', '1.0', 'https://example.com/schema')
            $scope.ToOtlp().schemaUrl | Should -Be 'https://example.com/schema'
        }

        It 'includes droppedAttributesCount as 0' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.ToOtlp().droppedAttributesCount | Should -Be 0
        }

        It 'returns an empty attributes array when no attributes are set' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.ToOtlp().attributes.Count | Should -Be 0
        }

        It 'serializes string attributes with stringValue' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('env', 'prod')
            $otlp = $scope.ToOtlp()
            $attr = $otlp.attributes | Where-Object { $_.key -eq 'env' }
            $attr.value.stringValue | Should -Be 'prod'
        }

        It 'serializes integer attributes with intValue' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('count', [int]5)
            $otlp = $scope.ToOtlp()
            $attr = $otlp.attributes | Where-Object { $_.key -eq 'count' }
            $attr.value.intValue | Should -Be 5
        }

        It 'serializes boolean attributes with boolValue' {
            $scope = [InstrumentationScope]::new('lib')
            $scope.SetAttribute('enabled', $true)
            $otlp = $scope.ToOtlp()
            $attr = $otlp.attributes | Where-Object { $_.key -eq 'enabled' }
            $attr.value.boolValue | Should -BeTrue
        }
    }
}
