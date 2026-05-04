import sys

path = "/Users/sakshamgoyal/development/SwiftCodeSan/Sources/SwiftCodeSanKit/Operations/UpdateAccessLevels.swift"
with open(path, 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'private let thinProtocolRequirements: Set<String> = [' in line:
        lines[i+1] = '    "==", "!=", "hash", "hashValue", "description", "debugDescription",\n'
        lines[i+2] = '    "encode", "id", "allCases", "rawValue", "subscript", "customMirror",\n'
        lines[i+3] = '    "makeIterator", "next", "compare", "advanced", "distance", "count", "isEmpty"\n'

with open(path, 'w') as f:
    f.writelines(lines)
