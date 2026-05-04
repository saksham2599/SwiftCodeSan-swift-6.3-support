# Test Cases for Fixed Issues

## Test 1: ImportRewriter Return Type Fix
Verifies that ImportRewriter correctly returns MissingDeclSyntax instead of wrapping it in DeclSyntax

## Test 2: RefChecker Import Extraction Fix
Verifies that imports are correctly extracted regardless of import form (selective vs plain)

## Test 3: DeclRemover Matching Logic Fix
Verifies that dead code detection works correctly even with formatting differences

## Manual Verification Steps

To test the fixes manually, we can create test files and run SwiftCodeSan on them:

### Test Import Detection
Create a file with unused imports:
```swift
import UIKit
import Foundation
import SomeUnusedFramework

let x = 42
```

Expected: UIKit and Foundation should be preserved (system frameworks), SomeUnusedFramework should be removed

### Test Dead Code Detection
Create a file with dead code:
```swift
public class UsedClass {
    public func method() {}
}

public class UnusedClass {
    public func unusedMethod() {}
}

let instance = UsedClass()
// UnusedClass is never used
```

Expected: UnusedClass should be removed, UsedClass should be preserved

### Test Access Level Updates
Create a file with over-exposed access levels:
```swift
public class InternalOnlyClass {
    public func internalMethod() {}
}

// InternalOnlyClass is only used within this module
// internalMethod is only called internally
```

Expected: InternalOnlyClass should be downgraded to internal, internalMethod should be downgraded to internal