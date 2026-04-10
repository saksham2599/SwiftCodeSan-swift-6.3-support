// ImportTests.swift — Tests for --remove-unused-imports functionality

import XCTest
import SwiftCodeSanKit
import Foundation

// MARK: - Helpers

private func runImportRemoval(
    libFiles: [String: String],   // filename -> content  (these become the "library" module)
    libModule: String,
    consumerContent: String,
    consumerModule: String = "Consumer"
) -> String {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftCodeSanImportTests_\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    var filesToModules = [String: String]()

    // Write library files
    for (name, content) in libFiles {
        let url = dir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        filesToModules[url.path] = libModule
    }

    // Write consumer file
    let consumerURL = dir.appendingPathComponent("Consumer.swift")
    try! consumerContent.write(to: consumerURL, atomically: true, encoding: .utf8)
    filesToModules[consumerURL.path] = consumerModule

    // Run tool  (in-place on consumer)
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

// MARK: - Test Class

class ImportRemovalTests: XCTestCase {

    // I1: Import is used via a direct type reference → PRESERVED
    func testI1_UsedDirectType() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class FooType {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            let x = FooType()
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I1 FAILED: used import was removed. Got:\n\(result)")
    }

    // I2: Import is genuinely unused → REMOVED
    func testI2_UnusedImport() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class FooType {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            let x = 10
            """
        )
        XCTAssertFalse(result.contains("import MyLib"),
                       "I2 FAILED: unused import was not removed. Got:\n\(result)")
    }

    // I3: Import used via typealias → PRESERVED
    func testI3_TypealiasUsage() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public typealias UserID = String"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            let uid: UserID = "abc"
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I3 FAILED: typealias-based import was removed. Got:\n\(result)")
    }

    // I4: Import used via property wrapper → PRESERVED
    func testI4_PropertyWrapperUsage() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": """
            @propertyWrapper public struct MyWrapper<T> {
                public var wrappedValue: T
                public init(wrappedValue: T) { self.wrappedValue = wrappedValue }
            }
            """],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            class MyView {
                @MyWrapper(wrappedValue: 0) var x: Int
            }
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I4 FAILED: property-wrapper import was removed. Got:\n\(result)")
    }

    // I5: Import used via qualified name (Module.Type) → PRESERVED
    func testI5_QualifiedName() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class FooType {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            let x = MyLib.FooType()
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I5 FAILED: qualified-name import was removed. Got:\n\(result)")
    }

    // I6: Import used only in return type → PRESERVED
    func testI6_ReturnTypeOnly() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class Thing {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            func makeThing() -> Thing { return Thing() }
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I6 FAILED: return-type-only import was removed. Got:\n\(result)")
    }

    // I7: Import used in generic constraint → PRESERVED
    func testI7_GenericConstraint() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public protocol Configurable {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            func configure<T: Configurable>(_ item: T) {}
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I7 FAILED: generic-constraint import was removed. Got:\n\(result)")
    }

    // I8: System framework whitelisted (Foundation) → always PRESERVED
    func testI8_SystemFrameworkWhitelisted() {
        let result = runImportRemoval(
            libFiles: [:],
            libModule: "UnusedModule",
            consumerContent: """
            import Foundation
            let x = 42
            """
        )
        XCTAssertTrue(result.contains("import Foundation"),
                      "I8 FAILED: whitelisted system import was removed. Got:\n\(result)")
    }

    // I9: Mixed — one used, one unused
    func testI9_MixedUsedAndUnused() {
        let result = runImportRemoval(
            libFiles: [
                "LibA.swift": "public class UsedType {}",
                "LibB.swift": "public class UnusedType {}"
            ],
            libModule: "LibA",
            consumerContent: """
            import LibA
            import LibB
            let x = UsedType()
            """
        )
        XCTAssertTrue(result.contains("import LibA"),
                      "I9 FAILED: used import LibA was removed. Got:\n\(result)")
        XCTAssertFalse(result.contains("import LibB"),
                       "I9 FAILED: unused import LibB was not removed. Got:\n\(result)")
    }

    // I10: Import used via inheritance → PRESERVED
    func testI10_InheritanceUsage() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class BaseClass {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            class Child: BaseClass {}
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I10 FAILED: inheritance-based import was removed. Got:\n\(result)")
    }

    // I11: Import used in extension conformance → PRESERVED
    func testI11_ExtensionConformance() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public protocol Trackable {}"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            class View {}
            extension View: Trackable {}
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I11 FAILED: extension-conformance import was removed. Got:\n\(result)")
    }

    // I12: Import used via class-level attribute → PRESERVED
    func testI12_ClassAttributeUsage() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "@resultBuilder public struct Builder { public static func buildBlock() {} }"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            @Builder class Container {}
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I12 FAILED: class-attribute import was removed. Got:\n\(result)")
    }

    // I13: @_exported import is NEVER removed
    func testI13_ExportedImportNeverRemoved() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class Foo {}"],
            libModule: "MyLib",
            consumerContent: """
            @_exported import MyLib
            let x = 42
            """
        )
        XCTAssertTrue(result.contains("@_exported import MyLib"),
                      "I13 FAILED: @_exported import was removed. Got:\n\(result)")
    }

    // I14: Selective import (import class Module.Symbol) is tracked — root module PRESERVED
    func testI14_SelectiveImportPreserved() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class Foo {}"],
            libModule: "MyLib",
            consumerContent: """
            import class MyLib.Foo
            let x = Foo()
            """
        )
        // The selective import should not be incorrectly treated as fully unused
        XCTAssertTrue(result.contains("import class MyLib.Foo"),
                      "I14 FAILED: selective import was removed. Got:\n\(result)")
    }

    // I15: Single type usage via static member access → PRESERVED
    func testI15_StaticMemberAccessPreserved() {
        let result = runImportRemoval(
            libFiles: ["Lib.swift": "public class Service { public static let shared = Service() }"],
            libModule: "MyLib",
            consumerContent: """
            import MyLib
            func run() { _ = Service.shared }
            """
        )
        XCTAssertTrue(result.contains("import MyLib"),
                      "I15 FAILED: static-member-access import was removed. Got:\n\(result)")
    }
}
