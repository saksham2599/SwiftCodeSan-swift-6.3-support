# SwiftCodeSan Usage Guide

SwiftCodeSan is a powerful code sanitizer for Swift that helps optimize visibility, remove unused imports, and delete dead code.

## 1. Build the Tool

First, build the tool using the Swift Package Manager:

```bash
swift build -c release
```
The binary will be located at `./.build/release/SwiftCodeSan`.

## 2. Generate the Mapping File

Before running any analysis, you must generate a mapping file that tells the tool which Swift file belongs to which module. This tool supports SPM projects, Monorepos, and single-target repositories.

```bash
# Point it to your project root
python3 generate_mapping.py <path_to_your_project> -o mapping.txt
```

## 3. Operations

### Visibility Optimization
Downgrades `public` or `open` declarations to `internal` or `package` if they are not used outside their module.

```bash
./.build/release/SwiftCodeSan --update-access-levels -f mapping.txt -i
```

### Unused Import Removal
Identifies and removes `import` statements that are not needed by the code in the file.

```bash
./.build/release/SwiftCodeSan --remove-unused-imports -f mapping.txt -i
```

### Dead Code Removal
Identifies and deletes functions, variables, and types that are never referenced in the project.

```bash
./.build/release/SwiftCodeSan --remove-deadcode -f mapping.txt -i
```

## 4. Key Flags

*   `-f, --files-to-modules`: Path to the mapping file (required).
*   `-i, --in-place`: Modifies the source files directly. Without this, the tool only reports findings.
*   `-j`: Maximum number of threads to use (defaults to CPU cores).
*   `-v`: Logging level (0=Info, 1=Verbose, 2=Warning, 3=Error).

## 5. Best Practices for Monorepos

1.  **Generate a Universal Mapping**: Run `generate_mapping.py` on the root of your monorepo to capture all internal dependencies.
2.  **Order of Operations**:
    1.  Run **Dead Code Removal** first to clean up the logic.
    2.  Run **Visibility Optimization** second.
    3.  Run **Unused Import Removal** last (as some imports may become unused after code is made internal or removed).
3.  **Verify**: Always check `git status` and run your test suite or `swift build` after a cleanup.
