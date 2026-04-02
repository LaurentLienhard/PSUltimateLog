---
project_name: 'PSUltimateLog'
date: '2026-04-02'
sections_completed:
  ['technology_stack', 'language_rules', 'testing_rules', 'quality_rules', 'workflow_rules', 'anti_patterns']
status: 'complete'
rule_count: 42
optimized_for_llm: true
---

# Contexte de projet pour agents IA — PSUltimateLog

_Ce fichier contient les règles critiques que les agents IA doivent suivre lors de l'implémentation de code dans ce projet. Il se concentre sur les détails non-évidents que les agents pourraient manquer._

---

## Stack technique & versions

| Outil | Version |
|-------|---------|
| PowerShell | 5.0+ (Desktop) / 7.x (Core) — **les deux doivent fonctionner** |
| Pester | latest (via `RequiredModules.psd1`) |
| PSScriptAnalyzer | latest |
| InvokeBuild | latest |
| ModuleBuilder | latest |
| Sampler + Sampler.GitHubTasks | latest |
| ChangelogManagement | latest |

---

## Règles d'implémentation critiques

### Règles PowerShell spécifiques

- `source/PSUltimateLog.psm1` doit rester **vide** — ModuleBuilder y fusionne tout au build ; tout code ajouté sera écrasé
- Les fichiers de classes **doivent avoir un préfixe numérique à deux chiffres** (`01_`, `02_`…) — seul mécanisme d'ordre de chargement
- Les classes dérivées doivent avoir un numéro **strictement supérieur** à leur classe de base (`07_ConsoleExporter` > `06_LogExporter`)
- PowerShell n'a pas de classes abstraites : simuler avec `throw [System.NotImplementedException]::new("message '$($this.GetType().Name)'")`
- Les méthodes `hidden` sont accessibles dans la classe mais invisibles à l'extérieur — utiliser pour l'initialisation interne (`Initialize`, `PopulateDefaults`)

**Compatibilité cross-version :**
- ❌ `[System.Convert]::ToHexString()` — indisponible sur .NET Framework (PS 5.0) → utiliser `[System.BitConverter]::ToString($bytes).Replace('-','').ToLower()`
- ❌ `$IsWindows` / `$IsMacOS` / `$IsLinux` sans guard → toujours utiliser `Get-Variable -Name 'IsWindows' -ValueOnly -ErrorAction SilentlyContinue`
- ❌ `[System.DateTimeOffset]::UnixEpoch` — indisponible sur .NET Framework → utiliser le calcul par ticks : `([System.DateTime]::UtcNow.Ticks - 621355968000000000L) * 100L`

**Types et collections :**
- Les timestamps OTel sont des `string` (pas `long`) pour éviter la perte de précision en JSON 64-bit
- Toujours caster `[long]` avant les opérations arithmétiques sur les nanosecondes : `([long]$nano / 100L)`
- Utiliser `[System.Collections.Generic.List[T]]::new()` plutôt que `@()` pour les collections mutables dans les classes

### Règles de tests

- **Un fichier de test par classe** : `tests/Unit/Classes/<ClassName>.tests.ps1`
- Tests d'intégration dans `tests/Integration/` — scénarios d'usage réels, pas de détails internes
- Ne jamais modifier `tests/QA/module.tests.ps1` — il valide PSScriptAnalyzer, manifest et help automatiquement

**Pattern obligatoire de BeforeAll dans chaque fichier de test :**
```powershell
BeforeAll {
    $projectPath = "$($PSScriptRoot)\..\..\..\" | Convert-Path
    if (-not $ProjectName) { $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath }
    Import-Module -Name $ProjectName -Force -ErrorAction Stop
}
```

**Mocking :**
- `InModuleScope $ProjectName { Mock Invoke-RestMethod {} }` requis pour mocker les cmdlets appelés depuis les classes
- Ne pas mocker les classes PowerShell directement — utiliser de vraies instances dans des états contrôlés (ex: exporter shut down = stub d'erreur)
- `$TestDrive` pour tout fichier temporaire — jamais de chemins hardcodés

**Couverture :**
- Seuil obligatoire : **85%** (enforced par `build.yaml` → `CodeCoverageThreshold: 85`)
- Les méthodes `hidden` doivent être couvertes indirectement via les méthodes publiques qui les appellent

### Règles de qualité et style

**Conventions de nommage :**
- Classes, méthodes, propriétés : `PascalCase`
- Paramètres de constructeurs/méthodes : `PascalCase` (ex: `[string]$Traceparent`)
- Variables locales : `camelCase` (ex: `$traceId`, `$otlpValue`)
- Fichiers de classes : `NN_ClassName.ps1` | Fichiers de tests : `ClassName.tests.ps1`

**Structure des classes (ordre obligatoire) :**
1. Constructeurs
2. Méthodes publiques
3. Méthodes `hidden`
4. Méthodes `static`

**Style :**
- Accolades ouvrantes sur leur propre ligne (style Allman)
- `if ($null -eq $obj)` — pas `if (!$obj)` ni `if (-not $obj)` pour les null checks
- Valider les paramètres obligatoires en début de constructeur avec `throw [System.ArgumentException]::new(...)`

**Sérialisation OTLP :**
- Attributs typés : `stringValue` | `intValue` (toujours `[long]`) | `doubleValue` | `boolValue`
- `droppedAttributesCount = 0` toujours présent — ne pas omettre
- `ToOtlp()` → `[hashtable]` | `ToOtlpJson()` → `[string]` compressé via `ConvertTo-Json -Depth 10 -Compress`

### Règles de workflow

**Build :**
```powershell
./build.ps1 -ResolveDependency -Tasks noop  # première fois uniquement
./build.ps1                                  # build + tests
./build.ps1 -Tasks build                     # build seul
./build.ps1 -Tasks test                      # tests seuls
```

**Checklist pour chaque nouvelle classe :**
1. Créer `source/Classes/NN_ClassName.ps1` avec le bon préfixe
2. Créer `tests/Unit/Classes/ClassName.tests.ps1`
3. Vérifier l'ordre de chargement (dérivées > base)
4. Mettre à jour `README.md`
5. Builder et vérifier couverture ≥ 85%
6. `git commit` + `git push`

**Checklist pour chaque nouvelle fonction publique :**
1. Créer `source/Public/Verb-Noun.ps1` (verbe PowerShell approuvé obligatoire)
2. Inclure `.SYNOPSIS`, `.DESCRIPTION` (> 40 chars), au moins un `.EXAMPLE`, `.PARAMETER` pour chaque paramètre
3. Ajouter le test dans `tests/Unit/Public/`

### Règles critiques à ne pas manquer

**Anti-patterns interdits :**
- ❌ Ajouter du code dans `source/PSUltimateLog.psm1`
- ❌ Accumuler dans une boucle avec `$array += $item` — utiliser `[List[T]]`
- ❌ Appels HTTP/réseau réels dans les tests unitaires
- ❌ `catch {}` vide sans commentaire explicatif (PSScriptAnalyzer `PSAvoidUsingEmptyCatchBlock`)
- ❌ `Write-Host` dans du nouveau code (PSScriptAnalyzer `PSAvoidUsingWriteHost`) — `ConsoleExporter` est l'unique exception justifiée

**Edge cases documentés :**
- `LogRecord` avec body `$null` → converti silencieusement en `''`
- `TraceContext` : trace-id et span-id tout-zéro invalides selon W3C → `ParseTraceparent` lève une exception
- `FileExporter.Export()` avec `$null` ou tableau vide → no-op, aucun fichier créé
- `Logger.Log()` : erreurs d'export → incrémentent `ExportErrors` sans interrompre la boucle
- `Logger.GetMetrics()` → retourne une copie ; muter le résultat n'affecte pas l'état interne

**Sécurité :**
- Ne jamais logger secrets, tokens ou mots de passe dans `Body` ou `attributes`
- `OtlpHttpExporter` envoie en clair — documenter l'exigence HTTPS en production
- `ResourceAttributes` expose des infos système (PID, hostname) — comportement attendu et documenté

---

## Directives d'utilisation

**Pour les agents IA :**
- Lire ce fichier avant d'implémenter tout code
- Suivre toutes les règles exactement telles que documentées
- En cas de doute, préférer l'option la plus restrictive
- Mettre à jour ce fichier si de nouveaux patterns émergent

**Pour les humains :**
- Garder ce fichier lean et focalisé sur les besoins des agents
- Mettre à jour lors de changements de stack technique
- Supprimer les règles devenues évidentes avec le temps

_Dernière mise à jour : 2026-04-02_
