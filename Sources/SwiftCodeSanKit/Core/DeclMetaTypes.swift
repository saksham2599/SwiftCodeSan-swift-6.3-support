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
import SwiftSyntax

/**
Decl metadata needed for decls in source code being parsed
*/

public typealias DeclMap = [String: [DeclMetadata]]

public enum DeclType {
    case protocolType, classType, extensionType, structType, enumType
    case typealiasType, patType
    case varType, subscriptType, funcType, initType, operatorType, enumCaseType
    case other
}

extension DeclType {
}
 
public enum AccessLevel: Int, Comparable, Sendable {
    case `private` = 0
    case `fileprivate` = 1
    case `internal` = 2
    case `package` = 3
    case `public` = 4
    case `open` = 5

    public static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public var isPublicOrOpen: Bool {
        return self == .public || self == .open
    }

    public var isPackageOrHigher: Bool {
        return self >= .package
    }

    public var keyword: String {
        switch self {
        case .private: return "private"
        case .fileprivate: return "fileprivate"
        case .internal: return "internal"
        case .package: return "package"
        case .public: return "public"
        case .open: return "open"
        }
    }
}

public final class DeclMetadata: Hashable, @unchecked Sendable {
    let name: String
    var type: String
    let fullName: String
    let declType: DeclType
    var inheritedTypes: [String]
    let boundTypes: [String]
    let boundTypesAL: [String]
    var members: [DeclMetadata] = []

    let path: String
    let module: String
    var package: String?
    let imports: [String]
    var encloser: String
    var declDescription: String
    var annotated: Bool = false
    var isInlinable: Bool = false
    var isUsableFromInline: Bool = false
    var isFrozen: Bool = false
    var isSPI: Bool = false
    var isAlwaysEmitIntoClient: Bool = false

    var isOverride: Bool
    var isExtensionMember: Bool = false
    var accessLevel: AccessLevel
    var targetAccessLevel: AccessLevel?
    var shouldExpose: Bool = false
    var visited: Bool = false
    var used: Bool = false

    public var isPublicOrOpen: Bool {
        return accessLevel.isPublicOrOpen
    }

    public var isPackageOrHigher: Bool {
        return accessLevel.isPackageOrHigher
    }

    @discardableResult
    func updateTargetAccessLevel(to newLevel: AccessLevel) -> Bool {
        if targetAccessLevel == nil || newLevel > targetAccessLevel! {
            targetAccessLevel = newLevel
            return true
        }
        return false
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullName)
        hasher.combine(declType)
        hasher.combine(encloser)
        hasher.combine(path)
        hasher.combine(module)
    }

    public static func == (lhs: DeclMetadata, rhs: DeclMetadata) -> Bool {
        if lhs.name == rhs.name,
            lhs.type == rhs.type,
            lhs.fullName == rhs.fullName,
            lhs.declType == rhs.declType,
            lhs.encloser == rhs.encloser,
            lhs.path == rhs.path,
            lhs.module == rhs.module {
            return true
        }
        return false
    }

    public init(path: String,
                module: String,
                package: String? = nil,
                imports: [String],
                encloser: String,
                name: String,
                type: String, 
                fullName: String,
                description: String,
                declType: DeclType,
                inheritedTypes: [String],
                boundTypes: [String],
                boundTypesAL: [String],
                accessLevel: AccessLevel,
                isOverride: Bool,
                annotated: Bool = false,
                isInlinable: Bool = false,
                isUsableFromInline: Bool = false,
                isFrozen: Bool = false,
                isSPI: Bool = false,
                isAlwaysEmitIntoClient: Bool = false,
                used: Bool = false) {
        self.path = path
        self.module = module
        self.package = package
        self.imports = imports
        self.encloser = encloser
        self.name = name
        self.type = type
        self.fullName = fullName
        self.declDescription = description
        self.declType = declType
        self.inheritedTypes = inheritedTypes
        self.boundTypes = boundTypes
        self.boundTypesAL = boundTypesAL
        self.annotated = annotated
        self.accessLevel = accessLevel
        self.isOverride = isOverride
        self.isInlinable = isInlinable
        self.isUsableFromInline = isUsableFromInline
        self.isFrozen = isFrozen
        self.isSPI = isSPI
        self.isAlwaysEmitIntoClient = isAlwaysEmitIntoClient
        self.used = used
    }
}

struct AnnotationMetadata {
    var module: String?
    var typeAliases: [String: String]?
    var varTypes: [String: String]?
}


public struct Whitelist: Sendable {
    public let thresholdDays: Int?
    public let decls: [String]?
    public let declsPrefix: [String]?
    public let declsSuffix: [String]?
    public let modules: [String]?
    public let modulesPrefix: [String]?
    public let modulesSuffix: [String]?
    public let inheritedTypes: [String]?
    public let members: [String]?

    public init(thresholdDays: Int?,
                decls: [String]?,
                 declsPrefix: [String]?,
                 declsSuffix: [String]?,
                 modules: [String]?,
                 modulesPrefix: [String]?,
                 modulesSuffix: [String]?,
                 inheritedTypes: [String]?,
                 members: [String]?) {
        self.thresholdDays = thresholdDays
        self.decls = decls
        self.declsPrefix = declsPrefix
        self.declsSuffix = declsSuffix
        self.modules = modules
        self.modulesPrefix = modulesPrefix
        self.modulesSuffix = modulesSuffix
        self.inheritedTypes = inheritedTypes
        self.members = members
    }

    func declWhitelisted(name: String, isMember: Bool, module: String?, parents: [String]?, path: String?) -> Bool {
        if let module = module {
            if let list = modules, list.contains(module) {
                return true
            }

            if let list = modulesPrefix {
                let moduleHasPrefix = !list.filter{module.hasPrefix($0)}.isEmpty
                if moduleHasPrefix { return true }
            }

            if let list = modulesSuffix {
                let moduleHasSuffix = !list.filter{module.hasSuffix($0)}.isEmpty
                if moduleHasSuffix { return true }
            }
        }

        if let parents = parents, let list = inheritedTypes {
            let inParentsList = !list.filter{ parents.contains($0) }.isEmpty
            if inParentsList { return true }
        }

        if isMember {
            if let list = members, list.contains(name) { return true }
        } else {
            if let list = decls, list.contains(name) { return true }
            if let list = declsPrefix {
                let declHasPrefix = !list.filter { name.hasPrefix($0) }.isEmpty
                if declHasPrefix { return true }
            }

            if let list = declsSuffix {
                let declHasSuffix = !list.filter { name.hasSuffix($0) }.isEmpty
                if declHasSuffix { return true }
            }
        }

        return false
    }
}


public func flatten(declMap: DeclMap) -> DeclMap {
    var flatDeclMap = DeclMap()

    func addDecl(_ decl: DeclMetadata) {
        if flatDeclMap[decl.name] == nil {
            flatDeclMap[decl.name] = []
        }
        if !(flatDeclMap[decl.name]?.contains(decl) ?? false) {
            flatDeclMap[decl.name]?.append(decl)
        }
        for m in decl.members {
            addDecl(m)
        }
    }

    for (_, vals) in declMap {
        for v in vals {
            addDecl(v)
        }
    }

    return flatDeclMap
}
