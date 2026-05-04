# SwiftCodeSan Analysis Report

## Overview
This document analyzes the current implementation of dead code detection, unused import detection, and access level removal in SwiftCodeSan.

## Current Implementation Analysis

### 1. Dead Code Detection (`--remove-deadcode`)

**Files involved:**
- `Sources/SwiftCodeSanKit/Operations/RemoveDeadDecls.swift`
- `Sources/SwiftCodeSanKit/Core/DeclRemover.swift`
- `Sources/SwiftCodeSanKit/Core/RefChecker.swift`

**How it works:**
1. **DeclParser** scans files and creates a `DeclMap` containing all declarations with metadata
2. **RefChecker** visits the AST to find all referenced declarations
3. **DeclRemover** removes declarations that are not referenced (dead code)

**Current Issues:**
- The `DeclRemover.shouldRemove()` function checks exact matches on:
  - name
  - encloser
  - fullName
  - description
  - declType
- This approach is fragile because:
  - Formatting differences in descriptions can cause false negatives
  - Full names might differ due to context
  - The comparison is too strict

### 2. Unused Import Detection (`--remove-unused-imports`)

**Files involved:**
- `Sources/SwiftCodeSanKit/Operations/RemoveUnusedImports.swift`
- `Sources/SwiftCodeSanKit/Core/ImportRewriter.swift`
- `Sources/SwiftCodeSanKit/Core/RefChecker.swift`

**How it works:**
1. **DeclParser** creates a declaration map
2. **RefChecker** tracks all imports and references
3. **ImportRewriter** removes imports that are not used

**Current Issues:**
- In `RefChecker.visit(_ node: ImportDeclSyntax)`, the import tracking has logic flaws:
  - Line 162-175: The logic for extracting module names from imports is inconsistent
  - For selective imports like `import class Foo.Bar`, it correctly takes "Foo" as module
  - For plain imports like `import Foo.Bar`, it takes "Foo" as module (good)
  - BUT it doesn't handle cases where the import might be used via dot notation (e.g., `Foo.Bar.someType`)
- The unused detection logic in `RemoveUnusedImports.swift` lines 94-130 has complex nested conditions that may miss edge cases
- System frameworks are protected by default, but the logic in `whitelistModulesBlock` (lines 61-91) may not work correctly

### 3. Access Level Removal (`--update-access-levels`)

**Files involved:**
- `Sources/SwiftCodeSanKit/Operations/UpdateAccessLevels.swift`
- `Sources/SwiftCodeSanKit/Core/AccessLevelRewriter.swift`

**How it works:**
1. **DeclParser** creates declaration maps
2. Multiple passes mark visibility and determine required access levels
3. **AccessLevelRewriter** updates access levels in the source

**Current Issues:**
- The access level calculation logic in `UpdateAccessLevels.swift` is extremely complex with multiple nested functions
- The logic for determining if a declaration should be exposed (`shouldExpose`) is spread across many functions
- There are potential infinite loops in the while loop (lines 97-108) if the convergence condition isn't met properly
- The bound type analysis (`updateBoundTypeALs`) may not correctly handle all cases

## Specific Bugs Identified

### Bug 1: ImportRemover Incorrect Return Type
In `Sources/SwiftCodeSanKit/Core/ImportRewriter.swift` line 63:
```swift
return DeclSyntax(MissingDeclSyntax(placeholder: .identifier("")))
```
**Issue:** `DeclSyntax` is not the correct return type for a `visit` method that should return `DeclSyntaxProtocol?`. The method should return the `MissingDeclSyntax` directly.

### Bug 2: Import Path Extraction Inconsistency
In `Sources/SwiftCodeSanKit/Core/RefChecker.swift` lines 158-177:
The import extraction logic has inconsistent handling:
- For selective imports, it takes the first path component
- For plain imports, it takes the first dot-separated component
- But it doesn't properly handle cases where imports are used with qualified names

### Bug 3: Dead Code Detection Too Strict
In `Sources/SwiftCodeSanKit/Core/DeclRemover.swift` lines 113-118:
The `shouldRemove` function requires exact matches on description and fullName, which can fail due to:
- Whitespace differences
- Formatting changes
- Contextual naming differences

### Bug 4: Missing System Framework Protection Logic
In `Sources/SwiftCodeSanKit/Operations/RemoveUnusedImports.swift` lines 61-91:
The `whitelistModulesBlock` function logic is overly complex and may not correctly identify when to protect system frameworks.

## Proposed Fixes

### Fix 1: ImportRewriter Return Type
Change line 63 in `ImportRewriter.swift` from:
```swift
return DeclSyntax(MissingDeclSyntax(placeholder: .identifier("")))
```
to:
```swift
return MissingDeclSyntax(placeholder: .identifier(""))
```

### Fix 2: Improve Import Usage Detection
Enhance the import tracking in `RefChecker` to better detect when imports are used via qualified names.

### Fix 3: Relax Dead Code Detection Criteria
Modify `DeclRemover.shouldRemove` to use more flexible matching that focuses on the essential identity of declarations rather than exact string matches.

### Fix 4: Simplify Import Protection Logic
Refactor the whitelist module checking logic to be more straightforward and reliable.

## Test Plan

After implementing fixes, we should run the existing test suites to ensure no regressions:
1. `AccessLevelTests.swift`
2. `DeadCodeTests.swift`
3. `ImportTests.swift` (if exists)

We should also add specific test cases for the bugs we identified.