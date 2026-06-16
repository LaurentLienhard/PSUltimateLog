# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PSUltimateLog** is a PowerShell module built with a modern CI/CD pipeline using Invoke-Build, ModuleBuilder, and Sampler. The module is designed for **PowerShell Core** (7.0+) to be cross-platform compatible with Windows, macOS, and Linux. It includes public functions, private utilities, classes, and enums with comprehensive unit tests.

## Code Standards & Architecture

### Language & Documentation

**All code, comments, documentation, examples, and variable names must be written in English**, regardless of conversation language. This ensures the codebase is accessible to all contributors.

### Object-Oriented Design with Classes

The architecture emphasizes **class-based design with public functions as interfaces**:

- **Classes** (`source/Classes/`) contain all business logic and data processing
  - Implement methods to handle core functionality
  - Use properties for state management
  - Leverage inheritance and composition for code reuse
  
- **Public Functions** (`source/Public/`) serve as thin wrappers
  - Accept user input and parameters
  - Instantiate appropriate classes
  - Call class methods to perform work
  - Return results to the pipeline
  
- **Private Functions** (`source/Private/`) provide helper utilities if needed
  - Should be minimal; prefer class methods instead
  - Used only for cross-cutting concerns (logging, validation helpers)

**Example Pattern:**
```powershell
# In source/Classes/LogProcessor.ps1
class LogProcessor {
    [string]$FilePath
    
    LogProcessor([string]$path) {
        $this.FilePath = $path
    }
    
    [void] Process() {
        # Business logic here
    }
}

# In source/Public/Invoke-LogProcessing.ps1
function Invoke-LogProcessing {
    param([string]$Path)
    
    $processor = [LogProcessor]::new($Path)
    $processor.Process()
}
```

## Build System

This project uses **Invoke-Build** as the task runner with configuration in `build.yaml`. The main build script is `build.ps1`.

### Setup & Dependencies

```powershell
# Bootstrap the environment (install required modules)
./build.ps1 -ResolveDependency -Tasks noop
```

This resolves dependencies defined in `RequiredModules.psd1` and `Resolve-Dependency.psd1`. Dependencies include:
- **InvokeBuild** — Task runner
- **ModuleBuilder** — Module building and merging
- **Pester** — Testing framework
- **PSScriptAnalyzer** — Code analysis
- **Sampler** & **Sampler.GitHubTasks** — Pre-built build tasks
- **DscResource.Test** — DSC resource testing utilities

### Common Commands

```powershell
# Run default task (build + test)
./build.ps1

# Build only
./build.ps1 -Tasks build

# Run tests only
./build.ps1 -Tasks test

# Run a specific test
./build.ps1 -Tasks Pester_Tests_Stop_On_Fail

# Pack module for distribution
./build.ps1 -Tasks pack

# View all available tasks
Invoke-Build -Tasks ?
```

### Build Workflow

The default build workflow (`.`) executes:
1. **build** — Clean, build module with ModuleBuilder, build nested modules, create changelog
2. **test** — Run Pester tests with code coverage validation (85% threshold)

Output artifacts go to `output/PSUltimateLog/` (versioned directory structure).

## Project Structure

```
source/
  ├── Classes/          # PowerShell classes (*.ps1 files)
  ├── Enum/             # PowerShell enumerations
  ├── Public/           # Public functions exported in module manifest
  ├── Private/          # Private functions not exported
  ├── Examples/         # Function usage examples
  ├── PSUltimateLog.psd1    # Module manifest
  └── PSUltimateLog.psm1    # Root module (auto-generated)

tests/
  ├── Unit/             # Pester unit tests
  │   ├── Public/       # Tests for public functions
  │   ├── Private/      # Tests for private functions
  │   └── Classes/      # Tests for classes
  └── QA/               # Quality assurance tests

.build/                 # Custom build tasks (if needed)
output/                 # Build output artifacts
  └── RequiredModules/  # Downloaded dependency modules
```

## Code Organization Patterns

### Public Functions
- Located in `source/Public/` with naming convention `<Verb>-<Noun>.ps1`
- Exported in module manifest
- Must include comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
- Use `[CmdletBinding()]` attribute for advanced function features
- Support `ShouldProcess` when modifying state

### Private Functions
- Located in `source/Private/` or referenced from Public functions
- Not exported in module manifest
- Called only from Public functions or other Private functions

### Classes
- Located in `source/Classes/` with numeric prefix (1.class1.ps1, 2.class2.ps1) to control load order
- Numeric prefix ensures proper dependency ordering during module build

### Enums
- Located in `source/Enum/`
- Provide type safety for function parameters

## Testing with Pester

Tests use **Pester 5** syntax with `BeforeAll`, `AfterAll`, `Describe`, `Context`, and `It` blocks.

```powershell
# Example test structure
BeforeAll {
    $moduleName = 'PSUltimateLog'
    Import-Module -Name $moduleName
}

Describe Get-Something {
    Context 'When condition' {
        It 'Should perform action' {
            # Use Should -Be, -Contain, -Throw, -Not -Throw, etc.
        }
    }
}
```

### Code Coverage

- Target threshold: **85%** (configured in `build.yaml`)
- Coverage reports in `output/`
- Code coverage is validated during the `test` workflow

### Running Tests Locally

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run tests with specific tag filter
./build.ps1 -Tasks Pester_Tests_Stop_On_Fail -PesterTag "MyTag"

# Run excluding certain tags
./build.ps1 -Tasks test -PesterExcludeTag "Integration"
```

## Adding New Functionality

### Creating a New Class

1. Create file in `source/Classes/` with numeric prefix: `<N>.<ClassName>.ps1`
   - Use numeric prefix to control class load order (classes with dependencies should have higher numbers)
   - Class names should follow PascalCase convention
2. Implement class with methods for all business logic
3. Create corresponding test file in `tests/Unit/Classes/<ClassName>.tests.ps1`
4. Write comprehensive tests covering all methods

### Creating a Public Function (Interface)

1. Create file in `source/Public/` named `<Verb>-<Noun>.ps1`
   - Function names follow Verb-Noun pattern (e.g., `Invoke-LogProcessing`, `Get-LogEntry`)
2. Function instantiates appropriate class and calls its methods
3. Add comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
4. Create corresponding test file in `tests/Unit/Public/<Verb>-<Noun>.tests.ps1`
5. Ensure tests pass and meet 85% code coverage threshold
6. Function is automatically exported during build (ModuleBuilder processes all Public functions)

## Key Files Reference

| File | Purpose |
|------|---------|
| `build.ps1` | Main build bootstrap script — entry point for all tasks |
| `build.yaml` | Build configuration: workflows, Pester settings, output structure |
| `RequiredModules.psd1` | Dependencies for build pipeline |
| `Resolve-Dependency.ps1` | Dependency resolution script (bootstraps modules) |
| `Resolve-Dependency.psd1` | Dependency resolution configuration |
| `source/PSUltimateLog.psd1` | Module manifest (version, author, exports) |
| `azure-pipelines.yml` | CI/CD pipeline definition |

## PowerShell Version & Compatibility

- **Required**: PowerShell Core 7.0 or later
- **Platforms**: Windows, macOS, and Linux
- Use modern PowerShell Core features without concern for backward compatibility with Windows PowerShell 5.0
- Ensure all code is cross-platform: avoid Windows-only APIs and cmdlets
- Use cross-platform compatible paths and file handling (prefer `[System.IO.Path]::Combine()` over string concatenation)

## Build Output Structure

After building, the module is available at:
```
output/PSUltimateLog/<version>/module/PSUltimateLog.psd1
```

The version directory is created automatically using semantic versioning.

## CI/CD Pipeline

The project uses **Azure Pipelines** for continuous integration (`azure-pipelines.yml`). The pipeline:
- Resolves dependencies
- Builds the module
- Runs Pester tests with code coverage validation
- Publishes to PowerShell Gallery (on release)
- Publishes GitHub releases

