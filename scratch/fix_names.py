import sys

path = "/Users/sakshamgoyal/development/SwiftCodeSan/Sources/SwiftCodeSanKit/Operations/UpdateAccessLevels.swift"
with open(path, 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'private let thinProtocolRequirements: Set<String> = [' in line:
        lines[i+1] = '    "==", "!=", "hash", "hashValue", "description", "debugDescription",\n'
        lines[i+2] = '    "encode", "id", "allCases", "rawValue",\n'
        lines[i+3] = '    "subscript"\n'
        # The list ended at i+3 or i+4. I'll just rewrite the whole block if needed.

# Actually, I'll just use a safer replacement
with open(path, 'w') as f:
    f.writelines(lines)
