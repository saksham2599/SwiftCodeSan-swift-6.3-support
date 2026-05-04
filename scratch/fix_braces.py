import sys

path = "/Users/sakshamgoyal/development/SwiftCodeSan/Sources/SwiftCodeSanKit/Operations/UpdateAccessLevels.swift"
with open(path, 'r') as f:
    content = f.read()

# The resolveInheritance function had misplaced braces at the end of the stdlib block.
# Let's find the whole function and replace it with a clean version.

new_func = """
private func resolveInheritance(target: DeclMetadata,
                                exploring: DeclMetadata,
                                declMap: DeclMap,
                                level: Int,
                                members: inout [DeclMetadata],
                                interfaceMembers: inout [DeclMetadata],
                                visited: inout Set<DeclMetadata>,
                                isSibling: Bool = false) {
    
    if visited.contains(exploring) { return }
    visited.insert(exploring)
    
    // Vertical inheritance (parents)
    for parent in exploring.inheritedTypes {
        if parent.isEmpty { continue }
        if let parentDecls = declMap[parent] {
            for parentDecl in parentDecls {
                if parentDecl.name.isEmpty { continue }
                if parentDecl.declType == .protocolType || parentDecl.declType == .classType || parentDecl.declType == .typealiasType {
                    if parentDecl.accessLevel >= .package, parentDecl.shouldExpose {
                        if parentDecl.declType == .protocolType {
                            interfaceMembers.append(contentsOf: parentDecl.members)
                        } else if parentDecl.declType == .classType, target.declType == .classType {
                            interfaceMembers.append(contentsOf: parentDecl.members)
                        }
                    }
                    
                    members.append(contentsOf: target.members)
                    let optionalInitialTypes = parentDecl.declType == .typealiasType ? parentDecl.boundTypesAL : nil
                    resolveInheritance(target: target, exploring: parentDecl, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, visited: &visited, isSibling: isSibling)
                }
            }
        } else {
            // Stdlib type found
            let stdlibType = parent
            let isThin = thinProtocols.contains(stdlibType) || stdlibType.hasPrefix("~")
            
            // lateral (sibling) conformances only protect the main type OR files that mention the protocol name.
            if isSibling && !isThin {
                let isMainFile = !target.path.contains("+") && !target.path.contains("_")
                let matchesPath = target.path.contains("+" + stdlibType) || target.path.contains(stdlibType + ".")
                if !isMainFile && !matchesPath {
                    continue
                }
            }

            for member in target.members {
                if member.accessLevel >= .package {
                    if !isThin || thinProtocolRequirements.contains(member.name) || member.name == "init" {
                        member.shouldExpose = true
                        member.updateTargetAccessLevel(to: member.accessLevel)
                        interfaceMembers.append(member)
                        members.append(member)
                    }
                }
            }
        }
    }

    // Lateral inheritance (sibling extensions)
    if exploring.declType != .protocolType {
        let key = exploring.declType == .extensionType ? exploring.name : exploring.name
        if !key.isEmpty, let siblingDecls = declMap[key], siblingDecls.count > 1 {
            for sibling in siblingDecls {
                if sibling.declType == .extensionType && sibling != exploring {
                    resolveInheritance(target: target, exploring: sibling, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, visited: &visited, isSibling: true)
                }
            }
        }
    }
}
"""

import re
start_marker = "private func resolveInheritance"
end_marker = "private func traverseMembers"
pattern = re.escape(start_marker) + r".*?(?=" + re.escape(end_marker) + r")"
content = re.sub(pattern, new_func + "\n\n", content, flags=re.DOTALL)

with open(path, 'w') as f:
    f.write(content)
