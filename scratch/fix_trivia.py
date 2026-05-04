import sys

path = "/Users/sakshamgoyal/development/SwiftCodeSan/Sources/SwiftCodeSanKit/Core/DeclRemover.swift"
with open(path, 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'return DeclSyntax(MissingDeclSyntax(placeholder: .identifier("")))' in line:
        indent = line[:line.find('return')]
        new_lines.append(f'{indent}return DeclSyntax(MissingDeclSyntax(placeholder: .identifier(""))\n')
        new_lines.append(f'{indent}    .with(\\.leadingTrivia, node.leadingTrivia)\n')
        new_lines.append(f'{indent}    .with(\\.trailingTrivia, node.trailingTrivia))\n')
    else:
        new_lines.append(line)

with open(path, 'w') as f:
    f.writelines(new_lines)
