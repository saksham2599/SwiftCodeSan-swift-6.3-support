// AccessLevelTests.swift — Tests for --update-access-levels functionality

import XCTest
import SwiftCodeSanKit
import Foundation

// MARK: - Helpers

private func runAccessLevelUpdate(
    files: [String: (content: String, module: String)],
    modulesToPackages: [String: String] = [:],
    whitelist: Whitelist? = nil
) -> [String: String] {  // returns filename -> updated content
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftCodeSanALTests_\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    var filesToModules = [String: String]()
    var urlMap = [String: URL]()

    for (name, info) in files {
        let url = dir.appendingPathComponent(name)
        try! info.content.write(to: url, atomically: true, encoding: .utf8)
        filesToModules[url.path] = info.module
        urlMap[name] = url
    }

    updateAccessLevels(
        filesToModules: filesToModules,
        modulesToPackages: modulesToPackages.isEmpty ? nil : modulesToPackages,
        whitelist: whitelist,
        inplace: true,
        logFilePath: nil,
        concurrencyLimit: 1,
        onCompletion: {}
    )

    var results = [String: String]()
    for (name, url) in urlMap {
        results[name] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    return results
}

// MARK: - Test Class

class AccessLevelTests: XCTestCase {

    // A1: public class only used within its own module → DOWNGRADED to internal
    func testA1_UnreferencedPublicClassDowngraded() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            public class Unused {}
            """, "ModA")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertFalse(content.contains("public class Unused"),
                       "A1 FAILED: unreferenced public class was not downgraded. Got:\n\(content)")
        XCTAssertFalse(content.contains("open class Unused"),
                       "A1 FAILED: unreferenced public class remained open. Got:\n\(content)")
    }

    // A2: public class used from another module → PRESERVED as public
    func testA2_CrossModulePublicClassPreserved() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            public class SharedType {}
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let x = SharedType()
            """, "ModB")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertTrue(content.contains("public class SharedType"),
                      "A2 FAILED: cross-module public class was incorrectly downgraded. Got:\n\(content)")
    }

    // A3: private var never touched
    func testA3_PrivateVarNotTouched() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            class Container {
                private var secret = 0
            }
            """, "ModA")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertTrue(content.contains("private var secret"),
                      "A3 FAILED: private var was modified. Got:\n\(content)")
    }

    // A4: internal var never touched (no keyword produces internal)
    func testA4_InternalVarNotTouched() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            class Container {
                var internalProp = 42
            }
            """, "ModA")
        ])
        let content = results["ModA.swift"] ?? ""
        // internal vars should not have a modifier added, and certainly not be made public
        XCTAssertFalse(content.contains("public var internalProp"),
                       "A4 FAILED: internal var was incorrectly made public. Got:\n\(content)")
    }

    // A5: package access — two modules in same package referenced → stays package (not downgraded to internal or upgraded to public)
    func testA5_PackageAccessPreserved() {
        let results = runAccessLevelUpdate(
            files: [
                "ModA.swift": ("""
                package class PackageType {}
                """, "ModA"),
                "ModB.swift": ("""
                import ModA
                let x = PackageType()
                """, "ModB")
            ],
            modulesToPackages: ["ModA": "MyPackage", "ModB": "MyPackage"]
        )
        let content = results["ModA.swift"] ?? ""
        // When accessed within the same package, target AL should be exactly package.
        XCTAssertTrue(content.contains("package class PackageType"),
                       "A5 FAILED: package class was incorrectly modified. Got:\n\(content)")
    }

    // A6: open class referenced externally stays open (not downgraded to public)
    func testA6_OpenClassRemainsOpen() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            open class BaseVC {}
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            class MyVC: BaseVC {}
            """, "ModB")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertTrue(content.contains("open class BaseVC"),
                      "A6 FAILED: open class was downgraded. Got:\n\(content)")
    }

    // A7: public protocol member accessed externally → PRESERVED
    func testA7_PublicProtocolMemberPreserved() {
        let results = runAccessLevelUpdate(files: [
            "Proto.swift": ("""
            public protocol Trackable {
                public func track()
            }
            """, "ModA"),
            "Consumer.swift": ("""
            import ModA
            class C: Trackable {
                public func track() {}
            }
            """, "ModB")
        ])
        let content = results["Proto.swift"] ?? ""
        XCTAssertTrue(content.contains("public protocol Trackable"),
                      "A7 FAILED: public protocol was downgraded. Got:\n\(content)")
    }

    // A8: A public class with init — init should also stay public
    func testA8_InitInheritsParentAccessLevel() {
        let results = runAccessLevelUpdate(files: [
            "ModA.swift": ("""
            public class APIClient {
                public init() {}
            }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let client = APIClient()
            """, "ModB")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertTrue(content.contains("public class APIClient"),
                      "A8 FAILED: public class was downgraded. Got:\n\(content)")
        XCTAssertTrue(content.contains("public init()"),
                      "A8 FAILED: public init was downgraded. Got:\n\(content)")
    }

    // A9: public func in extension, used cross-module → PRESERVED
    func testA9_PublicExtensionMemberPreserved() {
        let results = runAccessLevelUpdate(files: [
            "Ext.swift": ("""
            public class Widget {}
            public extension Widget {
                public func render() {}
            }
            """, "ModA"),
            "Usage.swift": ("""
            import ModA
            let w = Widget()
            w.render()
            """, "ModB")
        ])
        let content = results["Ext.swift"] ?? ""
        XCTAssertTrue(content.contains("public func render"),
                      "A9 FAILED: public extension method was downgraded. Got:\n\(content)")
    }

    // A10: whitelisted decl name — the specific decl should be preserved in its module
    func testA10_WhitelistedDeclPreservesAL() {
        let whitelist = Whitelist(
            thresholdDays: nil,
            decls: ["Whitelisted"],  // whitelist by decl name
            declsPrefix: nil,
            declsSuffix: nil,
            modules: nil,
            modulesPrefix: nil,
            modulesSuffix: nil,
            inheritedTypes: nil,
            members: nil
        )
        let results = runAccessLevelUpdate(
            files: [
                "ModA.swift": ("""
                public class Whitelisted {}
                """, "ModA")
            ],
            whitelist: whitelist
        )
        let content = results["ModA.swift"] ?? ""
        // Whitelisted decl should keep its access level unchanged
        XCTAssertTrue(content.contains("public class Whitelisted"),
                      "A10 FAILED: whitelisted decl class was modified. Got:\n\(content)")
    }
}
