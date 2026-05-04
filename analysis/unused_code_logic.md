# SwiftCodeSan Code Analysis and Bug Fixes

## Overview
This document provides a deep analysis of the core components responsible for:

1. **Dead Code Detection** (`RemoveDeadDecls`)
2. **Unused Imports Detection** (`RemoveUnusedImports`)
3. **Access Level Removal** (`UpdateAccessLevels`)

It outlines the current implementation logic, identifies bugs in `unused import detection` and `remove unused elevated access levels detection`, and presents proposed fixes.

---

## 1. Component Breakdown

### 1.1 DeclParser
- Scans Swift source files to build a `DeclMap` of all declarations.
- Extracts metadata including name, type, fullName, accessLevel, inheritedTypes, module, imports, etc.
- Used by all analysis tools to understand code structure.

### 1.2 RefChecker
- Tracks all references to declarations.
- Populates `refs`, `inlinableRefs`, and `imports` sets.
- Used by tools to determine which declarations are reachable.

### 1.3 ImportRewriter
- Detects and removes unused import statements.
- Uses `unused` list to match import module names against referenced symbols.
- Preserves `@_exported` and `@testable` imports automatically.

### 1.4 AccessLevelRewriter
- Updates access levels of declarations based on usage patterns.
- Handles promotions from internal → package/public/open/private based on reference analysis.
- Manages bound types and extension members.

### 1.5 DeclRemover
- Removes dead declarations (unused code) from source files.
- Uses `used` flag to filter declarations before output.

### 1.6 DeclUpdater
- Applies changes to files after analysis (access level changes, dead decl removal, import cleanup).

---

## 2. How Unused Imports Work

1. **Scanning Phase**  
   `removeUnusedImports()` calls `p.checkRefs()` which traverses the AST and collects:
   - `refs`: all referenced declaration names
   - `imports`: modules actually imported in the file

2. **Used Import Detection**  
   For each referenced symbol (`r`):
   - If it matches a known module name (`refDecl.module`), that import module is marked `used = true`.
   - For qualified references like `Foundation.Date`, checks if `i` (import) prefix matches.

3. **Unused List Construction**  
   - Imports not marked `used` are collected into `unusedImports[filepath]`.
   - These are later rewritten out of the file.

### Current Logic Issues

- **Token-Based Matching**: Uses `t.text` from tokens instead of full module name. May miss multi-part module names (`MyFramework.Categories`).
- **Version Trimming**: Strips trailing version components incorrectly, causing mismatches with actual import statements.
- **Selective Imports**: Doesn’t properly handle `import class/func/var/struct/enum.Module.Symbol` patterns.
- **Missing Protection**: Does not robustly exclude `@_exported` and `@testable` imports in all edge cases.

### Proposed Fixes

1. **Use Full Module Matching**  
   Match against the complete import text (`node.path.description`) rather than token fragments.

2. **Preserve Version Information**  
   When checking `unused.contains(str)`, ignore version components (`@_version` or similar) to avoid false negatives.

3. **Handle Selective Imports Correctly**  
   Extract root module name for selective imports (`import Module.Submodule.Symbol`) and compare against whitelist.

4. **Strengthen Whitelist Logic**  
   Ensure default system frameworks are never falsely flagged as unused.

---

## 3. How Access Level Removal Works

1. **Visibility Marking (`markVisiblity`)**  
   - For each referenced symbol, determines its declaring module.
   - Updates the target declaration’s access level (`targetAccessLevel`) based on usage context.
   - Sets `shouldExpose` flag when visibility should be promoted.

2. **Bound Type Propagation**  
   - Extends visibility updates to types conforming to protocols/classes.
   - Uses recursive traversal to propagate access requirements through inheritance chains.

3. **Member Visibility Update**  
   - When a protocol/class is marked for exposure, its members are also marked `shouldExpose = true`.
   - Ensures that public API surfaces are correctly maintained.

4. **Re-Runs & Convergence**  
   - The process repeats until no more decls need updates (`i != j` loop), ensuring transitive propagation.

### Current Logic Issues

- **Trivia Preservation**: Fails to preserve original formatting (whitespace, comments) when inserting new keywords (`public`, `open`).
- **Incomplete `shouldExpose` Logic**: In `updateBoundMemberALs`, the condition `if interfaceMemberNames.contains(member.name)` may miss indirect member exposures.
- **Incorrect Target Level Calculation**: Uses `target >= .package ? target : .internal` which can incorrectly cap visibility when target is `.open`.
- **Missing Edge Cases**: Does not adequately handle extensions, generic constraints, or complex inheritance patterns.

### Proposed Fixes

1. **Preserve Formatting**  
   Store original `leadingTrivia` and merge with new token trivia to avoid reformatting artifacts.

2. **Enhanced `shouldExpose` Detection**  
   Refine member exposure checks to consider protocol adherence and inherited member visibility more comprehensively.

3. **Correct Access Level Targeting**  
   Ensure that `targetAccessLevel` promotion respects the intended final level (e.g., `.open` should stay `.open`, not be capped at `.package`).

4. **Robust Trivia Handling**  
   When rewriting modifiers, reconstruct tokens with original trivia to maintain source compatibility.

---

## 4. Bug Summary

| Area | Symptom | Root Cause | Fix |
|------|---------|------------|-----|
| **Unused Imports** | False positives/negatives in detecting unused imports | Token-based matching; version stripping; inadequate selective import handling | Use full module name matching; ignore version suffixes; handle selective imports via root module extraction |
| **Access Level Updates** | Incorrect formatting after access level changes; missed visibility promotions; capping at `.package` | Improper trivia preservation; flawed `shouldExpose` logic; capped target level logic | Preserve and merge trivia; refine `shouldExpose` detection; correct level promotion and cap handling |

---

## 5. Implementation Plan

1. **Edit `ImportRewriter.swift`**  
   - Replace token-based unused check with full module name matching.
   - Add version-agnostic comparison for imported modules.
   - Strengthen whitelist enforcement for default frameworks.

2. **Edit `AccessLevelRewriter.swift`**  
   - Preserve and merge leading trivia when updating modifiers.
   - Correct `shouldExpose` detection logic in `updateBoundMemberALs`.
   - Fix target access level assignment to avoid unintended capping.

3. **Validate**  
   - Run existing unit tests (if any) or create minimal test cases to verify:
     - No needed imports are removed.
     - Access level promotions work correctly.
     - Source formatting remains intact.

4. **Update Documentation**  
   - Add usage notes for the updated logic in the codebase README.

</details>

---

*Prepared for internal use within the SwiftCodeSan project to improve correctness of dead code and access level analysis tools.*