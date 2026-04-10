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

extension CodeBlockItemSyntax.Item {
    func referencedTypes(with declMap: DeclMap, allowUnknown: Bool = false, filterKey: String? = nil) -> [String] {
        switch self {
        case .expr(let expr):
            return Syntax(expr).referencedTypes(with: declMap, allowUnknown: allowUnknown, filterKey: filterKey)
        case .decl(let decl):
            return Syntax(decl).referencedTypes(with: declMap, allowUnknown: allowUnknown, filterKey: filterKey)
        case .stmt(let stmt):
            return Syntax(stmt).referencedTypes(with: declMap, allowUnknown: allowUnknown, filterKey: filterKey)
        @unknown default:
            return []
        }
    }
}

protocol DeclProtocol {
    var type: String { get }
    var name: String { get }
    var fullName: String { get }
    var declType: DeclType { get }
    var inheritedTypes: [String] { get }
    func referencedTypes(with declMap: DeclMap, allowUnknown: Bool, filterKey: String?) -> [String]
    var refTypes: [String] { get }
    var boundTypes: [String] { get }
    var boundTypesAL: [String] { get } // Bound types for access levels
    var accessLevel: AccessLevel { get }
    var isOverride: Bool { get }
    var isExprOrStmt: Bool { get }
    func declMetadatas(path: String, module: String, encloser: String, description: String, imports: [String]) -> [DeclMetadata]
}

extension DeclProtocol {
    func declMetadatas(path: String, module: String, encloser: String, description: String, imports: [String]) -> [DeclMetadata] {
        if let declSyntax = self as? DeclSyntax, let varSyntax = declSyntax.as(VariableDeclSyntax.self) {
            return varSyntax.declMetadatas(path: path, module: module, encloser: encloser, description: description, imports: imports)
        }

        let val = DeclMetadata(path: path,
                                 module: module,
                                 imports: imports,
                                 encloser: encloser,
                                 name: name,
                                 type: type,
                                 fullName: fullName,
                                 description: description,
                                 declType: declType,
                                 inheritedTypes: inheritedTypes,
                                 boundTypes: boundTypes,
                                 boundTypesAL: boundTypesAL,
                                 accessLevel: accessLevel,
                                 isOverride: isOverride,
                                 used: false)
          return [val]
      }

    func referencedTypes(with declMap: DeclMap, allowUnknown: Bool = false, filterKey: String? = nil) -> [String] {
        return refTypes.filter { allowUnknown || declMap[$0] != nil || $0.contains(".") || $0.hasSuffix("Strings") || $0.hasSuffix("Images") }
    }

}

extension Syntax: DeclProtocol {

    var name: String {
        return ""
    }

    var type: String {
        return ""
    }

    var fullName: String {
        return name
    }

    var accessLevel: AccessLevel {
        return .internal
    }

    var isOverride: Bool {
        return false
    }

    var isExprOrStmt: Bool {
        return false
    }

    var declType: DeclType {
        return .other
    }

    var inheritedTypes: [String] {
        return []
    }

    var refTypes: [String] {
        return boundTypesAL
    }

    var boundTypes: [String] {
        return tokens(viewMode: .all).exprTokenList
    }

    var boundTypesAL: [String] {
        return boundTypes
    }
}

extension DeclSyntax: DeclProtocol {
    var name: String {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.name
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.name
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.name
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.name
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.name
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.name
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.name
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.name
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.name
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.name
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.name
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.name
        } else if let d = self.as(ActorDeclSyntax.self) {
            return d.name
        } else {
            return ""
        }
    }

    var type: String {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.type
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.type
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.type
        }
        return name
    }

    var fullName: String {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.fullName
        } else if let d = self.as(ActorDeclSyntax.self) {
            return d.fullName
        }
        return name
    }


    var declType: DeclType {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.declType
        } else if let d = self.as(ActorDeclSyntax.self) {
            return d.declType
        }
        return .other
    }


    var inheritedTypes: [String] {
        if let d = self.as(ProtocolDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.inheritedTypes
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.inheritedTypes
        }
        return []
    }

    func referencedTypes(with declMap: DeclMap, allowUnknown: Bool = false, filterKey: String? = nil) -> [String] {
        var list = refTypes
        if !declMap.isEmpty {
            list = list.filter{ allowUnknown || declMap[$0] != nil}
        }
        return list
    }

    var refTypes: [String] {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.refTypes
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.refTypes
        }
        return []
    }

    var boundTypes: [String] {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.boundTypes
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.boundTypes
        }
        return []
    }

    var boundTypesAL: [String] {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.boundTypesAL
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.boundTypesAL
        }
        return []
    }

    var accessLevel: AccessLevel {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(SubscriptDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(ProtocolDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(ClassDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(ExtensionDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(StructDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(EnumDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(EnumCaseDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(TypeAliasDeclSyntax.self) {
            return d.accessLevel
        } else if let d = self.as(AssociatedTypeDeclSyntax.self) {
            return d.accessLevel
        }
        return .internal
    }

    var isOverride: Bool {
        if let d = self.as(FunctionDeclSyntax.self) {
            return d.isOverride
        } else if let d = self.as(VariableDeclSyntax.self) {
            return d.isOverride
        } else if let d = self.as(InitializerDeclSyntax.self) {
            return d.isOverride
        }
        return false
    }

    var isExprOrStmt: Bool {
        _syntaxNode.is(StmtSyntax.self) || _syntaxNode.is(ExprSyntax.self)
    }
}


extension MemberBlockItemSyntax: DeclProtocol {
    var refTypes: [String] {
        return decl.refTypes
    }

    var declType: DeclType {
        return decl.declType
    }

    var inheritedTypes: [String] {
        return decl.inheritedTypes
    }

    var boundTypes: [String] {
        return decl.boundTypes
    }

    var boundTypesAL: [String] {
        return decl.boundTypesAL
    }

    var accessLevel: AccessLevel {
        return decl.accessLevel
    }

    var isOverride: Bool {
        return decl.isOverride
    }

    var isExprOrStmt: Bool {
        return decl.isExprOrStmt
    }

    var name: String {
        return decl.name
    }

    var type: String {
        return decl.type
    }

    var fullName: String {
        return decl.fullName
    }
}

extension MemberBlockItemListSyntax: DeclProtocol {

    var name: String {
        return ""
    }

    var type: String {
        return name
    }

    var fullName: String {
        return name
    }

    var declType: DeclType {
        return .other
    }

    var inheritedTypes: [String] {
        return []
    }

    var accessLevel: AccessLevel {
        return .internal
    }

    var isOverride: Bool {
        return false
    }

    var isExprOrStmt: Bool {
        return false
    }

    var boundTypes: [String] {
        return self.map { $0.decl.boundTypes }.flatMap{$0}
    }

    var boundTypesAL: [String] {
        return self.map { $0.decl.boundTypesAL }.flatMap{$0}
    }

    var refTypes: [String] {
        return boundTypesAL
    }

}

extension ProtocolDeclSyntax: DeclProtocol {
    var fullName: String {
        return name
    }
    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var name: String {
        return identifier.text.raw
    }
    
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var inheritedTypes: [String] {
        return [inheritanceClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter{$0 != name}
    }

    var boundTypes: [String] {
        return inheritedTypes
    }

    var boundTypesAL: [String] {
        return [boundTypes,
                memberBlock.members.boundTypesAL,
            ].compactMap{$0}.flatMap{$0}
    }

    var refTypes: [String] {
        return [boundTypesAL,
                attributes.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }

    var declType: DeclType {
        return .protocolType
    }
    
    var isPrivate: Bool {
        return self.modifiers.isPrivate
    }
    

    var attributesDescription: String {
        self.attributes.trimmedDescription ?? ""
    }
    
    var offset: Int64 {
        return Int64(self.position.utf8Offset)
    }
    
    func annotationMetadata(with annotation: String) -> AnnotationMetadata? {
        return leadingTrivia.annotationMetadata(with: annotation)
    }

}

extension ClassDeclSyntax: DeclProtocol {
    var fullName: String {
        return name
    }
    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }

    var isOverride: Bool {
        return false
    }

    var name: String {
        return identifier.text.raw
    }
    
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }
    
    var declType: DeclType {
        return .classType
    }
    
    var boundTypes: [String] {
        return inheritedTypes
    }

    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return [boundTypesAL,
                memberBlock.members.boundTypesAL,
                attributes.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}
    }


    var inheritedTypes: [String] {
        return [genericParameterClause?.parameters.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
                inheritanceClause?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}.filter{$0 != name}
    }

    var attributesDescription: String {
        self.attributes.trimmedDescription ?? ""
    }
    
    var offset: Int64 {
        return Int64(self.position.utf8Offset)
    }
    
    func annotationMetadata(with annotation: String) -> AnnotationMetadata? {
        return leadingTrivia.annotationMetadata(with: annotation)
    }
}

// MARK: - Actor Support (Swift 5.5+)
extension ActorDeclSyntax: DeclProtocol {
    // The `name` property in DeclProtocol returns String, shadowing ActorDeclSyntax.name (TokenSyntax).
    // We navigate to the name token via the actorKeyword's next sibling to avoid ambiguity.
    private var actorNameText: String {
        return actorKeyword.nextToken(viewMode: .all)?.text ?? ""
    }

    var fullName: String { return actorNameText }
    var type: String { return actorNameText }
    var isExprOrStmt: Bool { return false }
    var isOverride: Bool { return false }
    var name: String { return actorNameText }
    var accessLevel: AccessLevel { return self.modifiers.acl }
    var declType: DeclType { return .classType }  // Actors are reference types like classes

    var boundTypes: [String] { return inheritedTypes }
    var boundTypesAL: [String] { return boundTypes }

    var refTypes: [String] {
        return [boundTypesAL,
                memberBlock.members.boundTypesAL,
                attributes.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }

    var inheritedTypes: [String] {
        let actorName = actorNameText
        return [genericParameterClause?.parameters.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
                inheritanceClause?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}.filter{$0 != actorName}
    }

    var attributesDescription: String { self.attributes.trimmedDescription ?? "" }
    var offset: Int64 { return Int64(self.position.utf8Offset) }

    func annotationMetadata(with annotation: String) -> AnnotationMetadata? {
        return leadingTrivia.annotationMetadata(with: annotation)
    }
}

extension ExtensionDeclSyntax: DeclProtocol {
    var fullName: String {
        return extendedType.description.trimmed + "_" + inheritedTypes.joined()
    }
    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var name: String {
        let str = extendedType.description.trimmed.raw
        let comps = str.components(separatedBy: ".")
        if let last = comps.last, !last.isEmpty {
            return last
        }
        return str
    }

    var declType: DeclType {
        return .extensionType
    }
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var inheritedTypes: [String] {
        return [inheritanceClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter{$0 != name}
    }

    var boundTypes: [String] {
        var ret = inheritedTypes
        ret.append(name)
        return ret
    }

    var boundTypesAL: [String] {
        return [boundTypes,
                memberBlock.members.boundTypesAL,
            ].compactMap{$0}.flatMap{$0}
    }


    var refTypes: [String] {
        return boundTypesAL
    }

    func referencedTypes(with declMap: DeclMap, allowUnknown: Bool = false, filterKey: String? = nil) -> [String] {
        var list = [extendedType.tokens(viewMode: .all).exprTokenList,
                    refTypes
            ].compactMap{$0}.flatMap{$0}

        if !declMap.isEmpty {
            list = list.filter{ allowUnknown || declMap[$0] != nil}
        }

        return list
    }

}

extension EnumCaseDeclSyntax: DeclProtocol {
    var inheritedTypes: [String] {
        return []
    }

    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var name: String {
        let ret = elements.map{$0.identifier.text}.first ?? elements.description
        return ret.raw
    }

    var fullName: String {
        return self.elements.description
    }

    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var declType: DeclType {
        return .enumCaseType
    }

    var boundTypes: [String] {
        let list = elements.compactMap{$0.parameterClause?.parameters.flatMap{$0.type.tokens(viewMode: .all).exprTokenList}}.flatMap{$0}
        return list
    }

    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return boundTypesAL
    }
}

extension EnumDeclSyntax: DeclProtocol {
    var fullName: String {
        return name + "_" + inheritedTypes.joined()
    }
    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var attributesDescription: String {
        self.attributes.description.trimmed
    }

    var name: String {
        return identifier.text.trimmed.raw
    }
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var declType: DeclType {
        return .enumType
    }

    var inheritedTypes: [String] {
        return [inheritanceClause?.tokens(viewMode: .all).exprTokenList,
                genericParameterClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}.filter{ $0 != name }
    }

    var boundTypes: [String] {
        return inheritedTypes
    }

    var boundTypesAL: [String] {
        return [boundTypes,
                memberBlock.members.boundTypesAL
            ].compactMap{$0}.flatMap{$0}
    }

    var refTypes: [String] {
        return [boundTypesAL,
                attributes.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }
}

extension StructDeclSyntax: DeclProtocol {
    var fullName: String {
        return name + "_" + inheritedTypes.joined()
    }
    var type: String {
        return name
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var attributesDescription: String {
        self.attributes.description.trimmed
    }

    var name: String {
        return identifier.text.trimmed.raw
    }
    var declType: DeclType {
        return .structType
    }
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var inheritedTypes: [String] {
        return [inheritanceClause?.tokens(viewMode: .all).exprTokenList,
                genericParameterClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter{ $0 != name }
    }

    var boundTypes: [String] {
        return inheritedTypes
    }

    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return [boundTypesAL,
                memberBlock.members.boundTypesAL,
                attributes.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}
    }
}

extension AssociatedTypeDeclSyntax: DeclProtocol {
    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }
    var type: String {
        return name
    }

    var name: String {
        return identifier.text.trimmed.raw
    }

    var fullName: String {
        return name + "_" + boundTypes.joined()
    }

    var declType: DeclType {
        return .patType
    }

    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var inheritedTypes: [String] {
        return [inheritanceClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter{$0 != name}
    }

    var boundTypes: [String] {
        return [inheritedTypes,
                initializer?.value.tokens(viewMode: .all).exprTokenList.filter{$0 != name}
            ].compactMap{$0}.flatMap{$0}
    }

    var boundTypesAL: [String] {
        return boundTypes
    }
    var refTypes: [String] {
        return boundTypesAL
    }
}

extension TypeAliasDeclSyntax: DeclProtocol {
    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }
    var type: String {
        return name
    }

    var name: String {
        return identifier.text.trimmed.raw
    }

    var fullName: String {
        return name + "_" + boundTypes.joined()
    }

    var declType: DeclType {
        return .typealiasType
    }
    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var inheritedTypes: [String] {
        return [genericParameterClause?.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter{$0 != name}
    }

    var boundTypes: [String] {
        return [inheritedTypes,
                initializer.value.tokens(viewMode: .all).exprTokenList.filter{$0 != name}
            ].compactMap{$0}.flatMap{$0}
    }

    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return boundTypesAL
    }

}

extension PatternBindingSyntax {
    var type: String {
        if let t = typeAnnotation?.type.description.trimmed {
            return t
        }
        if let val = initializer?.value {
            if let expr = val.as(FunctionCallExprSyntax.self) {
                return expr.calledExpression.description.trimmed
            } else if let _ = ExprSyntax(val) {
                return val.description.trimmed
            }
        }
        return .unknownVal
    }

    func boundTypes(isTransparent: Bool) -> [String] {
        var list = [String]()
        if let bound = typeAnnotation?.type.tokens(viewMode: .all).exprTokenList {
            list.append(contentsOf: bound)
        }
        if let val = initializer?.value {
            if let expr = val.as(FunctionCallExprSyntax.self) {
                let exprList = [
                    expr.calledExpression.tokens(viewMode: .all).exprTokenList,
                    expr.arguments.map{$0.expression.tokens(viewMode: .all).exprTokenList}.flatMap{$0}
                    ].flatMap{$0}
                list.append(contentsOf: exprList)
            } else if let _ = ExprSyntax(val) {
                list.append(contentsOf: val.tokens(viewMode: .all).exprTokenList)
            }
        }

        if isTransparent {
            if let bodyTokens = accessorBlock?.tokens(viewMode: .all).exprTokenList {
                list.append(contentsOf: bodyTokens)
            }
        }
        return list
    }
}

extension VariableDeclSyntax: DeclProtocol {
    func declMetadatas(path: String, module: String, encloser: String, description: String, imports: [String]) -> [DeclMetadata] {
        var list = [DeclMetadata]()

        for binding in bindings {
            if let idpattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let id = idpattern.identifier.text
                if id == "_" { continue }
                let ty = binding.type
                let full = id + "_" + ty
                let bound = binding.boundTypes(isTransparent: isTransparent)
                let val = DeclMetadata(path: path,
                                       module: module,
                                       imports: imports,
                                       encloser: encloser,
                                       name: id,
                                       type: ty,
                                       fullName: full,
                                       description: description,
                                       declType: declType,
                                       inheritedTypes: inheritedTypes,
                                       boundTypes: bound,
                                       boundTypesAL: bound,
                                       accessLevel: accessLevel,
                                       isOverride: isOverride,
                                       used: false)
                list.append(val)
            } else if let tuple = binding.pattern.as(TuplePatternSyntax.self) {
                for el in tuple.elements {
                    if let idpattern = el.pattern.as(IdentifierPatternSyntax.self) {
                        let id = idpattern.identifier.text
                        if id == "_" { continue }

                        let ty = binding.type
                        let full = id + "_" + ty
                        let bound = binding.boundTypes(isTransparent: isTransparent)
                        let val = DeclMetadata(path: path,
                                               module: module,
                                               imports: imports,
                                               encloser: encloser,
                                               name: id,
                                               type: ty,
                                               fullName: full,
                                               description: description,
                                               declType: declType,
                                               inheritedTypes: inheritedTypes,
                                               boundTypes: bound,
                                               boundTypesAL: bound,
                                               accessLevel: accessLevel,
                                               isOverride: isOverride,
                                               used: false)
                        list.append(val)
                    }
                }
            }
        }

        return list
    }

    var isTransparent: Bool {
        return attributesDescription.contains(String.transparent)
    }

    var name: String {
        let ret = bindings.compactMap { $0.pattern.description.trimmed }.joined().raw
        return ret
    }

    var inheritedTypes: [String] {
        return []
    }

    var isExprOrStmt: Bool {
        return false
    }

    var fullName: String {
        return name + "_" + type
    }

    var declType: DeclType {
        return .varType
    }

    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var isOverride: Bool {
        return modifiers.isOverride
    }

    var attributesDescription: String {
        return attributes.trimmedDescription ?? ""
    }

    var type: String {
        return bindings.first?.type ?? ""
    }

    var boundTypes: [String] {
        var list = [String]()
        for b in bindings {
            list.append(contentsOf: b.boundTypes(isTransparent: isTransparent))
        }
        let attrs = attributes.tokens(viewMode: .all).exprTokenList
        list.append(contentsOf: attrs)
        return list.filter{$0 != name}
    }

    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        let ret = [boundTypesAL,
                bindings.compactMap{$0.accessorBlock?.tokens(viewMode: .all).exprTokenList}.flatMap{$0}
            ].compactMap{$0}.flatMap{$0}
        return ret
    }
}


extension FunctionDeclSyntax: DeclProtocol {
    var name: String {
        return self.identifier.description.trimmed.raw
    }

    var type: String {
        return signature.returnClause?.type.description.trimmed ?? ""
    }

    var fullName: String {
        return name + signature.description.trimmed
    }

    var declType: DeclType {
        if self.identifier.tokenKind == .binaryOperator(self.identifier.text) {
            return .operatorType
        }
        return .funcType
    }

    var accessLevel: AccessLevel {
        return self.modifiers.acl
    }

    var isOverride: Bool {
        return modifiers.isOverride
    }

    var attributesDescription: String {
        return attributes.trimmedDescription ?? ""
    }

    var inheritedTypes: [String] {
        return []
    }

    var isExprOrStmt: Bool {
        return false
    }

    var boundTypes: [String] {
        let genericParamTypes = genericParameterClause?.parameters.tokens(viewMode: .all).exprTokenList
        let genericWhereTypes = genericWhereClause?.tokens(viewMode: .all).exprTokenList
        let paramTypes = signature.parameterClause.parameters.flatMap{$0.type.tokens(viewMode: .all).exprTokenList}
        let paramVals = signature.parameterClause.parameters.flatMap{$0.defaultValue?.value.tokens(viewMode: .all).exprTokenList ?? []}
        let returnTypes = signature.returnClause?.type.tokens(viewMode: .all).exprTokenList
        let attrs = attributes.tokens(viewMode: .all).exprTokenList  // e.g. @FunctionBuilder
        var list = [genericParamTypes, genericWhereTypes, paramTypes, paramVals, returnTypes, attrs].compactMap{$0}.flatMap{$0}
        if attributesDescription.contains(String.transparent) {
            if let bodyTokens = body?.tokens(viewMode: .all).exprTokenList {
                list.append(contentsOf: bodyTokens)
            }
        }
        return list.filter{$0 != name}
    }
    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return [boundTypesAL,
                body?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }
}

extension InitializerDeclSyntax: DeclProtocol {
    var name: String {
        return "init"
    }
    var type: String {
        return name
    }

    var fullName: String {
        return name + "_" + signature.parameterClause.parameters.description.trimmed
    }

    var declType: DeclType {
        return .initType
    }

    var isOverride: Bool {
        return modifiers.isOverride
    }

    var attributesDescription: String {
        return attributes.trimmedDescription ?? ""
    }

    var accessLevel: AccessLevel {
        return modifiers.acl
    }

    var boundTypes: [String] {
        let genericParamTypes = genericParameterClause?.parameters.tokens(viewMode: .all).exprTokenList
        let genericWhereTypes = genericWhereClause?.tokens(viewMode: .all).exprTokenList

        var paramList = [String]()
        for param in signature.parameterClause.parameters {
            if let pval = param.defaultValue?.value {
                if let accessed = pval.as(MemberAccessExprSyntax.self), let base = accessed.base {
                    paramList.append(accessed.description.trimmed)
                    paramList.append(contentsOf: base.tokens(viewMode: .all).exprTokenList)
                } else {
                    paramList.append(contentsOf: pval.tokens(viewMode: .all).exprTokenList)
                }
            }
            paramList.append(contentsOf: param.type.tokens(viewMode: .all).exprTokenList)
        }

        var list = [genericParamTypes, genericWhereTypes, paramList].compactMap{$0}.flatMap{$0}

        // @_transparent on public or @usableFromInline functions require all types in sig and body to be public
        if attributesDescription.contains(String.transparent) {
            if let bodyTokens = body?.tokens(viewMode: .all).exprTokenList {
                list.append(contentsOf: bodyTokens)
            }
        }

        return list.filter{$0 != name}
    }
    var boundTypesAL: [String] {
        return boundTypes
    }

    var refTypes: [String] {
        return [boundTypesAL,
                body?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }

    var inheritedTypes: [String] {
        return []
    }

    var isExprOrStmt: Bool {
        return false
    }

    func isRequired(with declType: DeclType) -> Bool {
        if declType == .protocolType {
            return true
        } else if declType == .classType {
            let modifiers = self.modifiers
            if modifiers.isConvenience {
                return false
            }
            return modifiers.isRequired
        }
        return false
    }
}

extension SubscriptDeclSyntax: DeclProtocol {

    var fullName: String {
        return name + "_" + returnClause.type.description.trimmed
    }

    var name: String {
        return self.subscriptKeyword.text
    }

    var declType: DeclType {
        return .subscriptType
    }

    var accessLevel: AccessLevel {
        return modifiers.acl
    }

    var inheritedTypes: [String] {
        return []
    }

    var isExprOrStmt: Bool {
        return false
    }
    var isOverride: Bool {
        return false
    }

    var type: String {
        return returnClause.type.description.trimmed
    }

    var boundTypes: [String] {
        return [returnClause.type.tokens(viewMode: .all).exprTokenList,
                genericParameterClause?.parameters.tokens(viewMode: .all).exprTokenList,
                genericWhereClause?.tokens(viewMode: .all).exprTokenList,
                attributes.tokens(viewMode: .all).exprTokenList,
            ].compactMap{$0}.flatMap{$0}.filter {$0 != name }
    }

    var boundTypesAL: [String] {
        return boundTypes
    }


    var refTypes: [String] {
        return [boundTypesAL,
                accessorBlock?.tokens(viewMode: .all).exprTokenList
            ].compactMap{$0}.flatMap{$0}
    }

}


// MARK -

extension AttributeListSyntax {
    var trimmedDescription: String? {
        return self.trimmed.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

extension DeclModifierListSyntax {
    var acl: AccessLevel {
        for modifier in self {
            for token in modifier.tokens(viewMode: .all) {
                switch token.tokenKind {
                case .keyword(.public): return .public
                case .keyword(.package): return .package
                case .keyword(.internal): return .internal
                case .keyword(.private): return .private
                case .keyword(.fileprivate): return .fileprivate
                default:
                    // For some reason openKeyword option is not available in TokenKind so need to address separately
                    if token.text == String.open {
                        return .open
                    }
                }
            }
        }
        return .internal
    }

    var isStatic: Bool {
        return self.tokens(viewMode: .all).filter {$0.tokenKind == .keyword(.static) }.count > 0
    }

    var isRequired: Bool {
        return self.tokens(viewMode: .all).filter {$0.text == String.required }.count > 0
    }

    var isConvenience: Bool {
        return self.tokens(viewMode: .all).filter {$0.text == String.convenience }.count > 0
    }

    var isOverride: Bool {
        return self.tokens(viewMode: .all).filter {$0.text == String.override }.count > 0
    }

    var isFinal: Bool {
        return self.tokens(viewMode: .all).filter {$0.text == String.final }.count > 0
    }

    var isPrivate: Bool {
        return self.tokens(viewMode: .all).filter {$0.tokenKind == .keyword(.private) || $0.tokenKind == .keyword(.fileprivate) }.count > 0
    }

    var isPublic: Bool {
        return self.tokens(viewMode: .all).filter {$0.tokenKind == .keyword(.public) }.count > 0
    }

    var isOpen: Bool {
        return self.tokens(viewMode: .all).filter {$0.text == String.open }.count > 0
    }
}

extension Trivia {
    // This parses arguments in annotation which can be used to override certain types.
    //
    // E.g. given /// @mockable(typealias: T = Any; U = AnyObject), it returns
    // a dictionary: [T: Any, U: AnyObject] which will be used to override inhertied types
    // of typealias decls for T and U.
    private func metadata(with annotation: String, in val: String) -> AnnotationMetadata? {
        if val.contains(annotation) {
            let comps = val.components(separatedBy: annotation)
            var ret = AnnotationMetadata()
            if var argsStr = comps.last, !argsStr.isEmpty {
                if argsStr.hasPrefix("(") {
                    argsStr.removeFirst()
                }
                if argsStr.hasSuffix(")") {
                    argsStr.removeLast()
                }
                if argsStr.contains(String.typealiasColon), let subStr = argsStr.components(separatedBy: String.typealiasColon).last, !subStr.isEmpty {
                    ret.typeAliases = subStr.arguments(with: .annotationArgDelimiter)
                }
                if argsStr.contains(String.moduleColon), let subStr = argsStr.components(separatedBy: String.moduleColon).last, !subStr.isEmpty {
                    let val = subStr.arguments(with: .annotationArgDelimiter)
                    ret.module = val?[.prefix]
                }
                if argsStr.contains(String.rxColon), let subStr = argsStr.components(separatedBy: String.rxColon).last, !subStr.isEmpty {
                    ret.varTypes = subStr.arguments(with: .annotationArgDelimiter)
                }
                if argsStr.contains(String.varColon), let subStr = argsStr.components(separatedBy: String.varColon).last, !subStr.isEmpty {
                    if let val = subStr.arguments(with: .annotationArgDelimiter) {
                        if ret.varTypes == nil {
                            ret.varTypes = val
                        } else {
                            ret.varTypes?.merge(val, uniquingKeysWith: {$1})
                        }
                    }
                }
            }
            return ret
        }
        return nil
    }
    
    // Looks up an annotation (e.g. /// @mockable) and its arguments if any.
    // See metadata(with:, in:) for more info on the annotation arguments.
    func annotationMetadata(with annotation: String) -> AnnotationMetadata? {
        guard !annotation.isEmpty else { return nil }
        var ret: AnnotationMetadata?
        for i in 0..<count {
            let trivia = self[i]
            switch trivia {
            case .docLineComment(let val):
                ret = metadata(with: annotation, in: val)
                if ret != nil {
                    return ret
                }
            case .docBlockComment(let val):
                ret = metadata(with: annotation, in: val)
                if ret != nil {
                    return ret
                }
            default:
                continue
            }
        }
        return nil
    }
}


extension TokenSyntax {
    var stringToken: String? {
        if text == "self" || text == "Self" || text == "super" || text == "nil" ||
            text == "as" || text == "true" || text == "false" || text == "AnyObject" || text == "Any" {
            return nil
        }

        let startsWithLetter = text.first?.isLetter ?? false
        let validFirstChar = text.first == "_" || startsWithLetter
        if (validFirstChar && (text.isAlphanumeric || text.contains("_"))) ||
            tokenKind == .binaryOperator(text) {
            return text
        }

        return nil
    }

    var exprToken: String? {
        if tokenKind != .stringQuote,
            tokenKind != .stringSegment(text),
            tokenKind != .binaryOperator(text),
            tokenKind != .keyword(.`init`) {

            return stringToken
        }
        return nil
    }

    func filteredToken(with suffix: String) -> String? {
        if text.hasSuffix(suffix) {
            return String(text.dropLast(suffix.count))
        }
        return nil
    }
}

extension TokenSequence {
    var tokenList: [String] {
        return self.compactMap { $0.stringToken }
    }

    var exprTokenList: [String] {
        return self.compactMap { $0.exprToken }
    }
}



extension Syntax {
    var encloserName: String {
        var p = self.parent
        while let parent = p {
            if let decl = parent.as(ClassDeclSyntax.self) { return decl.name.description.trimmed }
            if let decl = parent.as(StructDeclSyntax.self) { return decl.name.description.trimmed }
            if let decl = parent.as(EnumDeclSyntax.self) { return decl.name.description.trimmed }
            if let decl = parent.as(ProtocolDeclSyntax.self) { return decl.name.description.trimmed }
            if let decl = parent.as(ExtensionDeclSyntax.self) { return decl.extendedType.description.trimmed }
            p = parent.parent
        }
        return ""
    }
}
