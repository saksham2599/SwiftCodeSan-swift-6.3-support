import Foundation
import SwiftSyntax
import SwiftParser

let code = """
// File header
import Foundation
import UIKit

/// Doc comment
public class MyClass {}
"""

let sourceFile = Parser.parse(source: code)

class TestRewriter: SyntaxRewriter {
    override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
        if node.path.description.contains("Foundation") {
            // Remove Foundation
            return DeclSyntax(MissingDeclSyntax(placeholder: .identifier("")))
        }
        return super.visit(node)
    }
}

let rewriter = TestRewriter()
let result = rewriter.visit(sourceFile)
print("--- Result with MissingDeclSyntax ---")
print(result.description)
print("-------------------------------------")

class ImprovedRewriter: SyntaxRewriter {
    override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
        if node.path.description.contains("Foundation") {
            // Remove Foundation but keep trivia
            return DeclSyntax(MissingDeclSyntax(placeholder: .identifier(""))
                .with(\.leadingTrivia, node.leadingTrivia)
                .with(\.trailingTrivia, node.trailingTrivia))
        }
        return super.visit(node)
    }
}

let improvedRewriter = ImprovedRewriter()
let improvedResult = improvedRewriter.visit(sourceFile)
print("--- Result with Improved Trivia Preservation ---")
print(improvedResult.description)
print("------------------------------------------------")
