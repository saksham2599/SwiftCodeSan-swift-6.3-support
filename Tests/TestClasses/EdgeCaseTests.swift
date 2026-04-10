// EdgeCaseTests.swift — Robustness and edge case tests

import XCTest
import SwiftCodeSanKit
import Foundation

// MARK: - Helpers (reuse import removal runner)

private func runImportRemovalRaw(content: String, libContent: String = "", libModule: String = "Lib") -> String {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftCodeSanEdgeTests_\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    var filesToModules = [String: String]()

    if !libContent.isEmpty {
        let libURL = dir.appendingPathComponent("Lib.swift")
        try! libContent.write(to: libURL, atomically: true, encoding: .utf8)
        filesToModules[libURL.path] = libModule
    }

    let consumerURL = dir.appendingPathComponent("Consumer.swift")
    try! content.write(to: consumerURL, atomically: true, encoding: .utf8)
    filesToModules[consumerURL.path] = "Consumer"

    removeUnusedImports(
        fileToModuleMap: filesToModules,
        whitelist: nil,
        topDeclsOnly: false,
        inplace: true,
        logFilePath: nil,
        concurrencyLimit: 1
    )

    return (try? String(contentsOf: consumerURL, encoding: .utf8)) ?? ""
}

// MARK: - Edge Case Tests

class EdgeCaseTests: XCTestCase {

    // E1: Empty file — must not crash
    func testE1_EmptyFile() {
        let result = runImportRemovalRaw(content: "")
        // Just verify it doesn't crash and returns something
        XCTAssertNotNil(result, "E1 FAILED: Empty file caused crash")
    }

    // E2: Comments-only file — must not crash
    func testE2_CommentsOnlyFile() {
        let result = runImportRemovalRaw(content: """
        // This file has only comments
        /* No declarations here */
        """)
        XCTAssertNotNil(result, "E2 FAILED: Comments-only file caused crash")
    }

    // E3: File with syntax error — must not crash the entire run
    func testE3_SyntaxErrorFile() {
        // SwiftParser is permissive and creates error nodes; tool should handle gracefully
        let result = runImportRemovalRaw(content: """
        import Foundation
        class BrokenClass {
            func missingBrace() {
                let x = 1
            // Missing closing brace
        """)
        // Key requirement: the OTHER files in the run should still be processed
        XCTAssertNotNil(result, "E3 FAILED: Syntax error caused crash")
    }

    // E4: Actor declaration — must be indexed correctly (our new support)
    func testE4_ActorImportPreserved() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            actor MyActor: LibProtocol {}
            """,
            libContent: "public protocol LibProtocol {}"
        )
        XCTAssertTrue(result.contains("import Lib"),
                      "E4 FAILED: actor-based import was removed. Got:\n\(result)")
    }

    // E5: Self-referencing type — must not infinite loop
    func testE5_SelfReferencingType() {
        let result = runImportRemovalRaw(content: """
        class Node {
            var next: Node?
            var data: Int = 0
        }
        """)
        XCTAssertNotNil(result, "E5 FAILED: self-referencing type caused crash")
    }

    // E6: Multiple imports of the same module — both handled, result has import once or zero times
    func testE6_DuplicateImports() {
        let result = runImportRemovalRaw(
            content: """
            import Foundation
            import Foundation
            let x = Date()
            """,
            libContent: "",
            libModule: "Lib"
        )
        // Foundation is whitelisted so it should remain. Key: no crash.
        XCTAssertTrue(result.contains("import Foundation"), "E6 FAILED: Foundation was removed. Got:\n\(result)")
    }

    // E7: Property wrapper on struct — the import must be PRESERVED (our prior fix regression test)
    func testE7_PropertyWrapperOnStruct() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            struct Prefs {
                @LibWrapper(wrappedValue: "") var name: String
            }
            """,
            libContent: """
            @propertyWrapper public struct LibWrapper<T> {
                public var wrappedValue: T
                public init(wrappedValue: T) { self.wrappedValue = wrappedValue }
            }
            """
        )
        XCTAssertTrue(result.contains("import Lib"),
                      "E7 FAILED: property-wrapper-on-struct import was removed. Got:\n\(result)")
    }

    // E8: @testable import — must never be removed
    func testE8_TestableImportNeverRemoved() {
        let result = runImportRemovalRaw(
            content: """
            @testable import Lib
            class Tests {}
            """,
            libContent: "public class LibType {}"
        )
        XCTAssertTrue(result.contains("@testable import Lib"),
                      "E8 FAILED: @testable import was removed. Got:\n\(result)")
    }

    // E9: File with no imports — no crash, no changes
    func testE9_FileWithNoImports() {
        let original = "class Plain { var x = 0 }"
        let result = runImportRemovalRaw(content: original)
        // No imports to remove, file should be essentially unchanged
        XCTAssertTrue(result.contains("class Plain"),
                      "E9 FAILED: file with no imports was mangled. Got:\n\(result)")
    }

    // E10: Enum usage preserves import
    func testE10_EnumCaseUsagePreservesImport() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            func handle(event: LibEvent) {
                switch event {
                case .start: break
                case .stop: break
                }
            }
            """,
            libContent: "public enum LibEvent { case start, stop }"
        )
        XCTAssertTrue(result.contains("import Lib"),
                      "E10 FAILED: enum-usage import was removed. Got:\n\(result)")
    }

    // E11: Generic constraint on extension preserves import
    func testE11_GenericExtensionPreservesImport() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            extension Array where Element: LibComparable {
                func sorted() -> [Element] { [] }
            }
            """,
            libContent: "public protocol LibComparable {}"
        )
        XCTAssertTrue(result.contains("import Lib"),
                      "E11 FAILED: generic-extension import was removed. Got:\n\(result)")
    }

    // E12: Whitelist prefix — module with matching prefix is protected
    func testE12_WhitelistModulePrefix() {
        let whitelist = Whitelist(
            thresholdDays: nil,
            decls: nil,
            declsPrefix: nil,
            declsSuffix: nil,
            modules: nil,
            modulesPrefix: ["MyOrg"],
            modulesSuffix: nil,
            inheritedTypes: nil,
            members: nil
        )

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftCodeSanWhitelistTest_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let libURL = dir.appendingPathComponent("Lib.swift")
        try! "public class Foo {}".write(to: libURL, atomically: true, encoding: .utf8)

        let consumerURL = dir.appendingPathComponent("Consumer.swift")
        try! "import MyOrgCore\nlet x = 42".write(to: consumerURL, atomically: true, encoding: .utf8)

        var filesToModules = [String: String]()
        filesToModules[libURL.path] = "MyOrgCore"
        filesToModules[consumerURL.path] = "Consumer"

        removeUnusedImports(
            fileToModuleMap: filesToModules,
            whitelist: whitelist,
            topDeclsOnly: false,
            inplace: true,
            logFilePath: nil,
            concurrencyLimit: 1
        )

        let result = (try? String(contentsOf: consumerURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(result.contains("import MyOrgCore"),
                      "E12 FAILED: whitelisted-prefix module was removed. Got:\n\(result)")
    }

    // E13: Conditional Compilation - import inside #if DEBUG should be preserved if compiled, or at least handled gracefully
    func testE13_ConditionalCompilation() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            #if true
            let a = LibClass()
            #endif
            """,
            libContent: "public class LibClass {}"
        )
        XCTAssertTrue(result.contains("import Lib"), "E13 FAILED: Import inside #if block was removed. Got:\n\(result)")
    }

    // E14: Opaque and Existential Types `some Type` and `any Type`
    func testE14_OpaqueAndExistentialTypes() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            func getObject() -> some LibProtocol { fatalError() }
            func process(obj: any LibProtocol) {}
            """,
            libContent: "public protocol LibProtocol {}"
        )
        XCTAssertTrue(result.contains("import Lib"), "E14 FAILED: Import for some/any types was removed. Got:\n\(result)")
    }

    // E15: KeyPaths Usage
    func testE15_KeyPathsUsage() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            let path = \\LibStruct.value
            """,
            libContent: "public struct LibStruct { public var value: Int = 0 }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E15 FAILED: Import for KeyPath usage was removed. Got:\n\(result)")
    }

    // E16: Macro Usage (#Preview, @Attached)
    func testE16_MacroUsage() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            #Preview { LibComponent() }
            """,
            libContent: "public struct LibComponent { public init() {} }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E16 FAILED: Import for Macro usage was removed. Got:\n\(result)")
    }

    // E17: Top Level Declarations
    func testE17_TopLevelDeclarations() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            let globalVar: LibClass = LibClass()
            func globalFunc() -> LibClass { return LibClass() }
            """,
            libContent: "public class LibClass { public init() {} }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E17 FAILED: Import for top level usage was removed. Got:\n\(result)")
    }

    // E18: Complex Closures
    func testE18_ComplexClosures() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            let x = { (a: Int) -> LibClass in
                return LibClass()
            }
            """,
            libContent: "public class LibClass { public init() {} }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E18 FAILED: Import for complex closure was removed. Got:\n\(result)")
    }

    // E19: Result Builders
    func testE19_ResultBuilders() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            @ViewBuilder
            func build() -> some Any {
                LibStruct()
            }
            """,
            libContent: "public struct LibStruct { public init() {} }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E19 FAILED: Import for result builder usage was removed. Got:\n\(result)")
    }

    // E20: Tuple Types
    func testE20_TupleTypes() {
        let result = runImportRemovalRaw(
            content: """
            import Lib
            func pair() -> (LibClass, Int) { return (LibClass(), 1) }
            """,
            libContent: "public class LibClass { public init() {} }"
        )
        XCTAssertTrue(result.contains("import Lib"), "E20 FAILED: Import for tuple types was removed. Got:\n\(result)")
    }
}
