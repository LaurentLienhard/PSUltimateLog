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

Describe 'InstrumentationScope' {

    Context 'Constructor(name, version)' {

        It 'sets Name correctly' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('MyLib', '1.0.0')
                $scope.Name | Should -Be 'MyLib'
            }
        }

        It 'sets Version correctly' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('MyLib', '1.0.0')
                $scope.Version | Should -Be '1.0.0'
            }
        }

        It 'leaves SchemaUrl empty' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('MyLib', '1.0.0')
                $scope.SchemaUrl | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Constructor(name, version, schemaUrl)' {

        It 'sets Name, Version, and SchemaUrl' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('MyLib', '2.0.0', 'https://opentelemetry.io/schemas/1.21.0')
                $scope.Name      | Should -Be 'MyLib'
                $scope.Version   | Should -Be '2.0.0'
                $scope.SchemaUrl | Should -Be 'https://opentelemetry.io/schemas/1.21.0'
            }
        }
    }

    Context 'Constructor validation' {

        It 'throws ArgumentException for null name' {
            InModuleScope $script:projectName {
                { [InstrumentationScope]::new($null, '1.0.0') } | Should -Throw -ExceptionType ([System.ArgumentException])
            }
        }

        It 'throws ArgumentException for empty name' {
            InModuleScope $script:projectName {
                { [InstrumentationScope]::new('', '1.0.0') } | Should -Throw -ExceptionType ([System.ArgumentException])
            }
        }

        It 'throws ArgumentException for whitespace-only name' {
            InModuleScope $script:projectName {
                { [InstrumentationScope]::new('   ', '1.0.0') } | Should -Throw -ExceptionType ([System.ArgumentException])
            }
        }
    }

    Context 'SetAttribute()' {

        It 'stores a key-value pair that is retrievable via ToOtlp()' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('MyLib', '1.0.0')
                $scope.SetAttribute('env', 'production')
                $otlp = $scope.ToOtlp()
                $attr = $otlp.attributes | Where-Object { $_.key -eq 'env' }
                $attr | Should -Not -BeNullOrEmpty
                $attr.value.stringValue | Should -Be 'production'
            }
        }
    }

    Context 'ToOtlp()' {

        It 'includes name and version' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('ScopeA', '3.1.4')
                $otlp = $scope.ToOtlp()
                $otlp.name    | Should -Be 'ScopeA'
                $otlp.version | Should -Be '3.1.4'
            }
        }

        It 'includes schemaUrl when set' {
            InModuleScope $script:projectName {
                $url = 'https://opentelemetry.io/schemas/1.21.0'
                $scope = [InstrumentationScope]::new('ScopeB', '1.0.0', $url)
                $otlp = $scope.ToOtlp()
                $otlp.schemaUrl | Should -Be $url
            }
        }

        It 'omits schemaUrl when empty' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('ScopeC', '1.0.0')
                $otlp = $scope.ToOtlp()
                $otlp.ContainsKey('schemaUrl') | Should -BeFalse
            }
        }

        It 'includes attributes array when attributes were added' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('ScopeD', '1.0.0')
                $scope.SetAttribute('region', 'eu-west-1')
                $otlp = $scope.ToOtlp()
                $otlp.ContainsKey('attributes') | Should -BeTrue
                $otlp.attributes.Count | Should -BeGreaterThan 0
            }
        }

        It 'omits attributes key when no attributes were added' {
            InModuleScope $script:projectName {
                $scope = [InstrumentationScope]::new('ScopeE', '1.0.0')
                $otlp = $scope.ToOtlp()
                $otlp.ContainsKey('attributes') | Should -BeFalse
            }
        }
    }
}
