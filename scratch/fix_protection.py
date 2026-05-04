import sys
import re

path = "/Users/sakshamgoyal/development/SwiftCodeSan/Sources/SwiftCodeSanKit/Operations/UpdateAccessLevels.swift"
with open(path, 'r') as f:
    content = f.read()

# Update resolveInheritance to pass a flag indicating if it's a sibling lookup
old_sig = """private func resolveInheritance(key cur: DeclMetadata,
                                inheritedTypes: [String]?,
                                declMap: DeclMap,
                                level: Int,
                                members: inout [DeclMetadata],
                                interfaceMembers: inout [DeclMetadata],
                                stdlibTypes: inout [String],
                                userDefinedTypes: inout [String]) {"""
new_sig = """private func resolveInheritance(key cur: DeclMetadata,
                                inheritedTypes: [String]?,
                                declMap: DeclMap,
                                level: Int,
                                members: inout [DeclMetadata],
                                interfaceMembers: inout [DeclMetadata],
                                stdlibTypes: inout [String],
                                userDefinedTypes: inout [String],
                                isSibling: Bool = false) {"""

content = content.replace(old_sig, new_sig)

# Update internal calls to pass isSibling=false for inheritance 
# and isSibling=true for extensions.
# Note: parentDecl.declType == .protocolType || ... is inheritance recursion
content = content.replace("resolveInheritance(key: parentDecl, inheritedTypes: optionalInitialTypes, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, stdlibTypes: &stdlibTypes, userDefinedTypes: &userDefinedTypes)",
                          "resolveInheritance(key: parentDecl, inheritedTypes: optionalInitialTypes, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, stdlibTypes: &stdlibTypes, userDefinedTypes: &userDefinedTypes, isSibling: isSibling)")

# extensionType recursion is lateral/sibling
content = content.replace("resolveInheritance(key: parentDecl, inheritedTypes: nil, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, stdlibTypes: &stdlibTypes, userDefinedTypes: &userDefinedTypes)",
                          "resolveInheritance(key: parentDecl, inheritedTypes: nil, declMap: declMap, level: level+1, members: &members, interfaceMembers: &interfaceMembers, stdlibTypes: &stdlibTypes, userDefinedTypes: &userDefinedTypes, isSibling: true)")

# Update the protection loop to use the isSibling flag and path heuristic
new_loop = """
    for stdlibType in stdlibTypes {
        if userDefinedTypes.contains(stdlibType) {
            continue
        }
        
        let isThin = thinProtocols.contains(stdlibType) || stdlibType.hasPrefix("~")
        
        // Lateral (sibling) conformances only protect the main type OR files that mention the protocol name.
        if isSibling && !isThin {
            let isMainFile = !cur.path.contains("+") && !cur.path.contains("_")
            let matchesPath = cur.declDescription.contains(stdlibType) || cur.path.contains(stdlibType)
            if !isMainFile && !matchesPath {
                continue
            }
        }

        for member in cur.members {
            if member.accessLevel >= .package {
                if !isThin || thinProtocolRequirements.contains(member.name) || member.name == "init" {
                    member.shouldExpose = true
                    member.updateTargetAccessLevel(to: member.accessLevel)
                    interfaceMembers.append(member)
                    members.append(member)
                }
            }
        }
        if !isThin {
            break
        }
    }
"""

# Replace the loop. Since I already modified it once, I'll use a more specific pattern.
pattern = r'for stdlibType in stdlibTypes \{.*?let isThin = .*?\}\s+if \!isThin \{.*?break\s+?\}\s+?\}'
# Actually, let's just replace the whole logic block after the loop over parents.
import re
# Look for the start of the stdlibTypes loop after the parents loop
pattern = r'\n\s+for stdlibType in stdlibTypes \{.*?if \!isThin \{\s+break\s+\}\s+\}'
content = re.sub(pattern, new_loop, content, flags=re.DOTALL)

with open(path, 'w') as f:
    f.write(content)
