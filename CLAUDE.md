# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This module uses the **Sampler** framework with **InvokeBuild** and **ModuleBuilder**.

```powershell
# First-time setup: resolve dependencies (only needed once or when RequiredModules.psd1 changes)
./build.ps1 -ResolveDependency -Tasks noop

# Full build + test (default workflow)
./build.ps1

# Build only (no tests)
./build.ps1 -Tasks build

# Test only
./build.ps1 -Tasks test

# Run a single test file
./build.ps1 -Tasks test -PesterScript 'tests/Unit/Classes/MyClass.tests.ps1'

# Run tests with a specific tag
./build.ps1 -Tasks test -PesterTag 'Unit'
```

The built module is output to `output/module/PSUltimateLog/<version>/`.

## Source layout

- `source/Classes/` — PowerShell classes, **loaded in numeric prefix order** (e.g. `01_`, `02_`). Load order matters: base classes must have a lower prefix than derived classes.
- `source/Public/` — Exported functions (cmdlet wrappers over the classes)
- `source/Private/` — Internal helper functions
- `source/PSUltimateLog.psd1` — Module manifest (source version; ModuleBuilder generates the final one in `output/`)
- `source/PSUltimateLog.psm1` — Root module (intentionally empty; ModuleBuilder merges everything into it at build time)

## Tests layout

- `tests/Unit/Classes/` — One test file per class, named `<ClassName>.tests.ps1`
- `tests/Unit/Public/` — Tests for public functions
- `tests/Unit/Private/` — Tests for private functions
- `tests/QA/module.tests.ps1` — Module-level QA tests (PSScriptAnalyzer, manifest, help)

Test files discover the module by scanning `*\*.psd1` and use `InModuleScope $ProjectName { }` to access internal classes.

## Language

All code, comments, documentation, commit messages, and file content must be written in **English**, regardless of the language used in conversation.

## Design philosophy

All logic must be implemented as **PowerShell classes** whenever possible. Processing belongs in **class methods**, not in standalone functions or scripts. Public functions in `source/Public/` are thin cmdlet wrappers that instantiate or call classes — they must not contain business logic themselves.

When adding a feature, default to:
1. Creating or extending a class in `source/Classes/`
2. Putting all logic in a method on that class
3. Exposing it via a minimal public function only if needed for the module's public API

## Function comment-based help

Every function must include a comment-based help block immediately after the `function` declaration line. The block must contain at minimum:

- `.SYNOPSIS`
- `.DESCRIPTION`
- `.PARAMETER` — one entry per parameter
- `.EXAMPLE` — **at least 4 diverse examples** covering typical use, edge cases, pipeline input, and advanced scenarios
- `.OUTPUTS`

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Short description.
    .DESCRIPTION
        Full description.
    .PARAMETER ParamName
        What this parameter does.
    .EXAMPLE
        Verb-Noun -ParamName 'value'
        Description of example 1.
    .EXAMPLE
        Verb-Noun -ParamName 'other'
        Description of example 2.
    .EXAMPLE
        'value' | Verb-Noun
        Description of example 3 (pipeline).
    .EXAMPLE
        Verb-Noun -ParamName 'advanced' -OtherParam $x
        Description of example 4 (advanced).
    .OUTPUTS
        [TypeName] Description.
    #>
    ...
}
```

## Key constraints

- **Code coverage threshold is 70%** — enforced by the build pipeline (`build.yaml` → `CodeCoverageThreshold: 85`). New classes require corresponding Pester tests.
- **Class load order is controlled by numeric filename prefix** — always prefix class files (e.g. `01_Foo.ps1`, `02_Bar.ps1`). Derived classes must have a higher number than their base.
- **`source/PSUltimateLog.psm1` must remain empty** — ModuleBuilder merges all classes and functions into it at build time. Do not add code there directly.
- **PSScriptAnalyzer** runs as part of QA tests — settings in `.vscode/analyzersettings.psd1`.

## Version control

- **Always run `git push` after committing** — every commit must be pushed to keep the GitHub repository in sync with local changes.
