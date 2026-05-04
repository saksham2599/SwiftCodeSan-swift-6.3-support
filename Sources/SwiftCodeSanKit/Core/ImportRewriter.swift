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
Updates import statements in source code
*/

public final class ImportRewriter: SyntaxRewriter {
    let unused: [String]

    public init(_ path: String, unusedModules: [String]?) {
        self.unused = unusedModules ?? []
    }

    override public func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
        // Never remove @_exported imports — they are used to re-export symbols to consumers
        // Never remove @testable imports — they are required for test access
        let attrDescriptions = node.attributes.map { $0.description }
        let hasProtectedAttribute = attrDescriptions.contains(where: {
            $0.contains("_exported") || $0.contains("testable")
        })
        if hasProtectedAttribute {
            return super.visit(node)
        }

        // Determine the root module name to match against the unused list
        let importPath = node.path.description.trimmed
        var moduleName = importPath

        if node.importKindSpecifier != nil {
            // Selective import: `import class Foo.Bar` → module is "Foo"
            if let firstComponent = node.path.first?.name.text {
                moduleName = firstComponent
            }
        } else {
            // Plain import (could be `import Foo` or `import Foo.Bar`)
            // Use the first dot‑separated component as the module name
            let parts = importPath.components(separatedBy: ".")
            if !parts.isEmpty {
                moduleName = parts[0]
            }
        }

        if unused.contains(moduleName) {
            return DeclSyntax(MissingDeclSyntax(placeholder: .identifier(""))
                .with(\.leadingTrivia, node.leadingTrivia)
                .with(\.trailingTrivia, node.trailingTrivia))
        }

        return super.visit(node)
    }
}
