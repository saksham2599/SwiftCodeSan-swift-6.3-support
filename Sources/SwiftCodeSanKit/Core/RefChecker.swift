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
Checks for referenced decls
*/

final class RefChecker: SyntaxVisitor {
    var imports = [String]()
    private var declMap = DeclMap()
    private var path: String
    private var module: String
    private var reflist = [String]()
    var refs: Set<String> {
        return Set(reflist)
    }
    private var inlinableReflist = [String]()
    var inlinableRefs: Set<String> {
        return Set(inlinableReflist)
    }
    
    private var inlinableStack = [Bool]()
    private var isInlinable: Bool {
        return inlinableStack.last ?? false
    }
    
    init(_ path: String, module: String, declMap: DeclMap) {
        self.path = path
        self.module = module
        self.declMap = declMap
        super.init(viewMode: .all)
    }

    private func addRefs(_ newRefs: [String]) {
        reflist.append(contentsOf: newRefs)
        if isInlinable {
            inlinableReflist.append(contentsOf: newRefs)
        }
    }

    override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
        if node.item.is(ExprSyntax.self) || node.item.is(StmtSyntax.self) {
            addRefs(node.item.referencedTypes(with: declMap, allowUnknown: true))
            return .skipChildren
        }

        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        if node.isOverride {
            addRefs([node.name])
        }

        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let nodeInlinable = node.attributesDescription.contains(String.inlinable)
        inlinableStack.append(isInlinable || nodeInlinable)
        
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        if node.isOverride {
            addRefs([node.name])
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: FunctionDeclSyntax) {
        inlinableStack.removeLast()
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let nodeInlinable = node.attributesDescription.contains(String.inlinable)
        inlinableStack.append(isInlinable || nodeInlinable)
        
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }
    
    override func visitPost(_ node: SubscriptDeclSyntax) {
        inlinableStack.removeLast()
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let nodeInlinable = node.attributesDescription.contains(String.inlinable)
        inlinableStack.append(isInlinable || nodeInlinable)
        
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        if node.isOverride {
            addRefs([node.name])
        }
        return .visitChildren
    }
    
    override func visitPost(_ node: InitializerDeclSyntax) {
        inlinableStack.removeLast()
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
         addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
         return .visitChildren
     }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        addRefs([node.name])
        return .visitChildren
    }
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        addRefs(node.referencedTypes(with: declMap, allowUnknown: true))
        return .visitChildren
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        // For selective imports like `import class Foundation.NSObject`, extract
        // the root module name (the first path component, e.g. "Foundation")
        // so it is tracked and never incorrectly removed.
        if node.importKindSpecifier != nil {
            // Selective import: `import class/func/var/struct/enum/typealias Module.Symbol`
            if let rootModule = node.path.first?.name.text {
                imports.append(rootModule)
            }
        } else if node.attributes.isEmpty {
            // Plain import with no attributes: `import ModuleName`
            let str = node.path.description.trimmed
            imports.append(str)
        } else {
            // @testable or @_exported import — track the module so it is not
            // considered unused, but the ImportRewriter will never remove them.
            if let rootModule = node.path.first?.name.text {
                imports.append(rootModule)
            }
        }
        return .skipChildren
    }
}
