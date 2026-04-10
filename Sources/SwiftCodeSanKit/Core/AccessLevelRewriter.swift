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
 Updates access levels in the source code
 */
public final class AccessLevelRewriter: SyntaxRewriter {
    var decls: [DeclMetadata]
    let path: String
    let module: String
    public init(_ path: String, module: String?, decls: [DeclMetadata]) {
        self.path = path
        self.module = module ?? ""
        self.decls = decls
    }

    private func updateModifiers(_ name: String, encloser: String, fullName: String, description: String, declType: DeclType, modifiers: DeclModifierListSyntax) -> (updated: DeclModifierListSyntax, leadingTrivia: Trivia?, isModified: Bool)? {
        let declMetadata = decls.first(where: { (d: DeclMetadata) -> Bool in
            return d.name == name && d.encloser == encloser && d.fullName == fullName && d.declDescription == description && d.declType == declType
        })

        if let d = declMetadata {
            var isModified = false
            var list = [DeclModifierSyntax]()
            var preservedTrivia: Trivia?

            let targetAL = d.targetAccessLevel ?? .internal
            for modifier in modifiers {
                let modText = modifier.name.text
                if modText == String.public || modText == String.open || modText == "package" {
                    isModified = true
                    if preservedTrivia == nil {
                        preservedTrivia = modifier.leadingTrivia
                    }
                } else {
                    var m = modifier
                    if let trivia = preservedTrivia {
                        m.leadingTrivia = trivia + m.leadingTrivia
                        preservedTrivia = nil
                    }
                    list.append(m)
                }
            }
            
            if targetAL >= .package {
                let keyword = TokenSyntax.keyword(targetAL == .open ? .open : (targetAL == .public ? .public : .package))
                var newModifier = DeclModifierSyntax(name: keyword.with(\.trailingTrivia, .spaces(1)))
                if let trivia = preservedTrivia {
                    newModifier.leadingTrivia = trivia
                    preservedTrivia = nil
                }
                list.insert(newModifier, at: 0)
                isModified = true
            }

            return (DeclModifierListSyntax(list), preservedTrivia, isModified)
        }
        return nil
    }

    private func updateNode<T: DeclSyntaxProtocol>(_ node: T,
                                                  name: (T) -> String,
                                                  encloser: (T) -> String,
                                                  fullName: (T) -> String,
                                                  description: (T) -> String,
                                                  declType: (T) -> DeclType,
                                                  modifiers: (T) -> DeclModifierListSyntax,
                                                  withModifiers: (T, DeclModifierListSyntax) -> T,
                                                  keyword: (T) -> TokenSyntax,
                                                  withKeyword: (T, TokenSyntax) -> T) -> T {
        if let (updatedModifier, leadingTrivia, isModified) = updateModifiers(name(node), encloser: encloser(node), fullName: fullName(node), description: description(node), declType: declType(node), modifiers: modifiers(node)) {
            var updatedNode = node
            if isModified {
                updatedNode = withModifiers(updatedNode, updatedModifier)
                if let trivia = leadingTrivia {
                    let k = keyword(updatedNode)
                    updatedNode = withKeyword(updatedNode, k.with(\.leadingTrivia, trivia + k.leadingTrivia))
                }
            }
            return updatedNode
        }
        return node
    }

    override public func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { _ in "" },
                                 encloser: { _ in "" },
                                 fullName: { _ in "" },
                                 description: { $0.description },
                                 declType: { _ in .extensionType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.extensionKeyword },
                                 withKeyword: { $0.with(\.extensionKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { _ in "" },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.enumKeyword },
                                 withKeyword: { $0.with(\.enumKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { _ in "" },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.structKeyword },
                                 withKeyword: { $0.with(\.structKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: ProtocolDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { _ in "" },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.protocolKeyword },
                                 withKeyword: { $0.with(\.protocolKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { _ in "" },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.classKeyword },
                                 withKeyword: { $0.with(\.classKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: ActorDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { _ in "" },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.actorKeyword },
                                 withKeyword: { $0.with(\.actorKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { Syntax($0).encloserName },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.funcKeyword },
                                 withKeyword: { $0.with(\.funcKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: SubscriptDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { Syntax($0).encloserName },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.subscriptKeyword },
                                 withKeyword: { $0.with(\.subscriptKeyword, $1) })
        return super.visit(updated)
    }
    
    override public func visit(_ node: InitializerDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { Syntax($0).encloserName },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.initKeyword },
                                 withKeyword: { $0.with(\.initKeyword, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { Syntax($0).encloserName },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.bindingSpecifier },
                                 withKeyword: { $0.with(\.bindingSpecifier, $1) })
        return super.visit(updated)
    }

    override public func visit(_ node: TypeAliasDeclSyntax) -> DeclSyntax {
        let updated = updateNode(node,
                                 name: { $0.name },
                                 encloser: { Syntax($0).encloserName },
                                 fullName: { $0.fullName },
                                 description: { $0.description },
                                 declType: { $0.declType },
                                 modifiers: { $0.modifiers },
                                 withModifiers: { $0.with(\.modifiers, $1) },
                                 keyword: { $0.typealiasKeyword },
                                 withKeyword: { $0.with(\.typealiasKeyword, $1) })
        return super.visit(updated)
    }
}
