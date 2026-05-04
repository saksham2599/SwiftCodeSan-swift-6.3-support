//
//  Copyright (c) 2018. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
private let thinProtocols: Set<String> = [
    "Sendable", "Equatable", "Hashable", "Comparable", "CustomStringConvertible",
    "CustomDebugStringConvertible", "CustomReflectable", "Encodable", "Decodable",
    "Codable", "Identifiable", "Error", "AnyObject", "Copyable", "Escapable",
    "BitwiseCopyable", "CaseIterable", "RawRepresentable", "ExpressibleByArrayLiteral",
    "ExpressibleByStringLiteral", "ExpressibleByDictionaryLiteral", "ExpressibleByIntegerLiteral",
    "ExpressibleByFloatLiteral", "ExpressibleByBooleanLiteral", "ExpressibleByNilLiteral"
]

private let thinProtocolRequirements: Set<String> = [
    "==", "!=", "hash", "hashValue", "description", "debugDescription",
    "encode", "id", "allCases", "rawValue", "subscript", "customMirror",
    "makeIterator", "next", "compare", "advanced", "distance", "count", "isEmpty"
]


nonisolated(unsafe) private var nref = 0

public func updateAccessLevels(filesToModules: [String: String],
                               modulesToPackages: [String: String]? = nil,
                               whitelist: Whitelist?,
                               inplace: Bool,
                               logFilePath: String? = nil,
                               concurrencyLimit: Int? = nil,
                               onCompletion: @Sendable @escaping () -> ()) {
    
    scanConcurrencyLimit = concurrencyLimit
    let p = DeclParser()
    var pathToDeclsUpdate = [String: [DeclMetadata]]()
    
    log("Scan and map top-level decls...")
    logTime()
    let declMap = p.scanAndMapDecls(fileToModuleMap: filesToModules,
                                    moduleToPackageMap: modulesToPackages,
                                    topDeclsOnly: false,
                                    whitelist: whitelist)
    
    logTime()
    
    log("Check references, look up their source modules, and mark visibility...")
    p.checkRefs(fileToModuleMap: filesToModules, declMap: declMap) { @Sendable (path, refs, inlinableRefs, imports) in
        if let refModule = filesToModules[path] {
            let refPackage = modulesToPackages?[refModule]
            markVisiblity(refs, inlinableRefs: inlinableRefs, in: refModule, package: refPackage, imports: imports, with: declMap, updateMembers: true)
        }
    }
    
    logTime()
    
    log("Update ALs (access levels) of top-level decls and their bound types...")
    updateBoundTypeALs(declMap: declMap)
    resetVisited(declMap: declMap)
    
    log("Update ALs of member decls of interfaces (protocol / base class)...")
    updateMemberALs(declMap: declMap)
    
    logTime()
    
    log("Flatten decls, and check references again, for member decls...")
    nref = 0
    let flatDeclMap = flatten(declMap: declMap)
    p.checkRefs(fileToModuleMap: filesToModules, declMap: flatDeclMap) { @Sendable (path, refs, inlinableRefs, imports) in
        if let refModule = filesToModules[path] {
            let refPackage = modulesToPackages?[refModule]
            markVisiblity(refs, inlinableRefs: inlinableRefs, in: refModule, package: refPackage, imports: imports, with: flatDeclMap, updateMembers: false)
        }
        log(counter: &nref, interval: 1000)
    }
    log(nref)
    
    logTime()
    
    log("Update ALs of all decls and their bound types...")
    updateBoundTypeALs(declMap: flatDeclMap)
    resetVisited(declMap: flatDeclMap)
    
    var i = -1
    var j = 0
    
    while i != j {
        log("If bound types are modified, update their member ALs as well...")
        updateMemberALs(declMap: declMap)
        i = flatDeclMap.values.flatMap{$0}.filter{$0.shouldExpose}.count
        
        log("Again, update ALs of of all decls and their bound types...")
        updateBoundTypeALs(declMap: flatDeclMap)
        resetVisited(declMap: flatDeclMap)
        j = flatDeclMap.values.flatMap{$0}.filter{$0.shouldExpose}.count
        
        log("#Remaining decls to update", i-j, i, j)
    }
    
    log("Save decls to update per files...")
    for (_, decls) in flatDeclMap {
        for decl in decls {
            let targetAL = decl.targetAccessLevel ?? .internal
            if targetAL < decl.accessLevel {
                if pathToDeclsUpdate[decl.path] == nil {
                    pathToDeclsUpdate[decl.path] = []
                }
                decl.targetAccessLevel = targetAL
                pathToDeclsUpdate[decl.path]?.append(decl)
            }
        }
    }
    
    if let logfile = logFilePath {
        log("Save results to", logfile)
        let ret = pathToDeclsUpdate.map {"\($0.key): \($0.value.map{$0.name + ", " + $0.encloser}.joined(separator: "\n"))"}.joined(separator: "\n")
        try? ret.write(toFile: logfile, atomically: true, encoding: .utf8)
    }
    
    if inplace {
        let updater  = DeclUpdater()
        updater.updateAccessLevels(filesToDecls: pathToDeclsUpdate, filesToModules: filesToModules) { @Sendable (path, content) in
            try? content.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    logTime()
    
    let total = pathToDeclsUpdate.values.flatMap{$0}.count
    log("#Total top-level decls: ", declMap.count, "#Total decls", flatDeclMap.count, "#Decls updated", total, "#Files updated", pathToDeclsUpdate.count)
    logTotalElapsed("Done")
    
    onCompletion()
}


// MARK - private functions

private func updateBoundTypeALs(declMap: DeclMap) {
    for (k, decls) in declMap {
        if !k.isEmpty {  // Empty means expr or stmt
            for decl in decls {
                if decl.accessLevel >= .package || decl.shouldExpose ||
                    decl.declType == .extensionType ||
                    decl.isExtensionMember {
                    decl.visited = true
                    updateBoundTypeALs(decl, level: 0, declMap: declMap)
                }
            }
        }
    }
}

private func updateBoundTypeALs(_ decl: DeclMetadata, level: Int, declMap: DeclMap) {
    
    for boundType in decl.boundTypesAL {
        if !boundType.isEmpty {
            var bases: [String]?
            var leaf: String?
            if boundType.contains(".") {
                bases = boundType.components(separatedBy: ".")
                leaf = bases?.removeLast()
            }
            
            let key = leaf ?? boundType
            
            if let boundDecls = declMap[key] {
                for boundDecl in boundDecls {
                    let target = decl.targetAccessLevel ?? .internal
                    let requiredAL: AccessLevel = target >= .package ? target : .internal
                    
                    let didPromote = boundDecl.updateTargetAccessLevel(to: requiredAL)
                    
                    if !boundDecl.visited || didPromote {
                        boundDecl.visited = true
                        if decl.module == boundDecl.module || decl.imports.contains(boundDecl.module) {
                            boundDecl.shouldExpose = true
                            updateBoundTypeALs(boundDecl, level: level + 1, declMap: declMap)
                        }
                    }
                }
            }
        }
    }
}

private func updateMemberALs(declMap: DeclMap) {
    for (_, vals) in declMap {
        for cur in vals {
            var members = [DeclMetadata]()
            var interfaceMembers = [DeclMetadata]()
            let level = 0
            
            updateBoundMemberALs(key: cur, declMap: declMap, level: level, members: &members, interfaceMembers: &interfaceMembers)
        }
    }
}

private func updateBoundMemberALs(key cur: DeclMetadata,
                                  declMap: DeclMap,
                                  level: Int,
                                  members: inout [DeclMetadata],
                                  interfaceMembers: inout [DeclMetadata]) {
    
    // First resolve inheritance (loop up protocol conformance, subclassing, and update member ALs)
    var parents = cur.inheritedTypes
    let curIsExtension = cur.declType == .extensionType
    if curIsExtension {
        parents.append(cur.name)
    }
    var visited = Set<DeclMetadata>()
            resolveInheritance(target: cur, exploring: cur, declMap: declMap, level: level, members: &members, interfaceMembers: &interfaceMembers, visited: &visited, isSibling: false)
    
    let interfaceMemberNames = interfaceMembers.map{$0.name}
    for member in members {
        if interfaceMemberNames.contains(member.name) {
            if member.accessLevel >= .package || (curIsExtension && cur.accessLevel >= .package) {
                member.shouldExpose = true
                member.updateTargetAccessLevel(to: member.accessLevel)
                
                // If encloser is extension, it should be also exposed since its member is public/exposed
                if curIsExtension, !cur.shouldExpose {
                    cur.shouldExpose = true
                }
            }
        } else if member.accessLevel >= .package, member.isOverride {
            // This might be a member overriding stdlib api
            member.shouldExpose = true
            member.updateTargetAccessLevel(to: member.accessLevel)
        }
    }
    
    // For the following decl types, check bound types and update member ALs.
    if cur.declType == .extensionType || cur.declType == .enumType {
        
        var visitedCurrent = false
        let boundTypesAL = cur.boundTypesAL.filter{!cur.inheritedTypes.contains($0)}
        
        for boundType in boundTypesAL {
            if !boundType.isEmpty, cur.name != boundType, let boundTypeVals = declMap[boundType] {
                for boundDecl in boundTypeVals {
                    if !visitedCurrent,
                       boundDecl.isPackageOrHigher,
                       boundDecl.shouldExpose {
                        
                        for member in cur.members {
                            if member.accessLevel >= .package {
                                member.shouldExpose = true
                                member.updateTargetAccessLevel(to: member.accessLevel)
                            }
                        }
                        visitedCurrent = true
                    }
                }
            } else if !visitedCurrent, cur.inheritedTypes.contains(boundType) {
                // If parent is not in declMap, assume it's in stdlib.
                for member in cur.members {
                    if member.accessLevel >= .package {
                        member.shouldExpose = true
                        member.updateTargetAccessLevel(to: member.accessLevel)
                    }
                }
                visitedCurrent = true
            }
        }
        
        if visitedCurrent, !cur.shouldExpose {
            cur.shouldExpose = true
        }
    }
}





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


private func traverseMembers(_ bases: [String], _ i: Int, _ refModule: String, _ refPackage: String?, _ imports: [String], declMap: DeclMap, isInlinable: Bool) -> Bool {
    let j = i + 1
    
    if j < bases.count {
        let cur = bases[i]
        let next = bases[j]
        if let prefixDecls = declMap[cur] {
            for prefixDecl in prefixDecls {
                var list: [DeclMetadata]?
                if prefixDecl.declType == .funcType ||
                    prefixDecl.declType == .operatorType ||  // This is handled here but shouldn't be member-accessed
                    prefixDecl.declType == .varType {
                    if let typeDecls = declMap[prefixDecl.type] {
                        for t in typeDecls {
                            list = t.members.filter{$0.name == next}
                        }
                    }
                } else {
                    list = prefixDecl.members.filter{$0.name == next}
                }
                
                if let list = list, !list.isEmpty {
                    if traverseMembers(bases, i + 1, refModule, refPackage, imports, declMap: declMap, isInlinable: isInlinable) {
                        for member in list {
                            let updated: Bool
                            if refModule == member.module {
                                let level: AccessLevel = isInlinable ? member.accessLevel : .internal
                                updated = member.updateTargetAccessLevel(to: level)
                            } else if member.package != nil && member.package == refPackage {
                                updated = member.updateTargetAccessLevel(to: .package)
                            } else if imports.contains(member.module) {
                                let level: AccessLevel = (member.accessLevel == .open) ? .open : .public
                                updated = member.updateTargetAccessLevel(to: level)
                                if updated { member.shouldExpose = true }
                            } else {
                                updated = false
                            }

                            if updated {
                                member.members.filter({$0.name == "init"}).forEach { $0.updateTargetAccessLevel(to: member.targetAccessLevel ?? .internal) }
                            }
                        }
                    }
                    
                } else {
                    return false
                }
            }
        }
    }
    return true
}

private func markVisiblity(_ refs: Set<String>, inlinableRefs: Set<String>, in refModule: String, package refPackage: String?, imports: [String], with declMap: DeclMap, updateMembers: Bool) {
    // Leaf level node checks
    for r in refs {
        
        var bases: [String]?
        var leaf: String?
        
        if r.contains(".") {
            bases = r.components(separatedBy: ".")
        }
        
        // First, traverse member access, and update visibility along the way
        var accessedMembers = false
        if let bases = bases {
            accessedMembers = traverseMembers(bases, 0, refModule, refPackage, imports, declMap: declMap, isInlinable: inlinableRefs.contains(r))
        }
        if accessedMembers {
            continue
        }
        
        leaf = bases?.removeLast()
        let refKey = leaf ?? r
        
        // If above fails (e.g. encloser type is not found), or non-member access, try following
        if let refDecls = declMap[refKey] {
            for refDecl in refDecls {
                if refDecl.isPackageOrHigher ||
                    refDecl.declType == .extensionType ||
                    refDecl.isExtensionMember {
                    
                    // multi modules w/ same decls (foo):
                    // 1. shadowing: if ref'd, it uses a decl in the same module even if the others are imported.
                    //      - if foo from another module should be called, it's required to use qualifier X.foo
                    // 2. if not decl's in the same module as ref, uses corresponding modules, so need to look up imports
                    // 3. if foo inits are the same for multi-modules:
                    //     - need qualifier X.foo
                    if refModule == refDecl.module {
                        let level: AccessLevel = inlinableRefs.contains(r) ? refDecl.accessLevel : .internal
                        refDecl.updateTargetAccessLevel(to: level)
                    } else if refDecl.package != nil && refDecl.package == refPackage {
                        if refDecl.updateTargetAccessLevel(to: .package) {
                            refDecl.members.filter({$0.name == "init"}).forEach { $0.updateTargetAccessLevel(to: .package) }
                        }
                    } else if imports.contains(refDecl.module) {
                        let level: AccessLevel = (refDecl.accessLevel == .open) ? .open : .public
                        if refDecl.updateTargetAccessLevel(to: level) {
                            refDecl.shouldExpose = true
                            refDecl.members.filter({$0.name == "init"}).forEach { $0.updateTargetAccessLevel(to: level) }
                        }
                    }
                    
                }
            }
        }
    }
}


private func shouldMatchACLForMembers(_ declType: DeclType) -> Bool {
    return declType == .protocolType ||
        declType == .extensionType ||
        declType == .enumType
}

private func resetVisited(declMap: DeclMap) {
    for (_, decls) in declMap {
        for decl in decls {
            decl.visited = false
        }
    }
}
