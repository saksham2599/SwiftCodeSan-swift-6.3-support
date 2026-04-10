// DeadCodeTests.swift — Tests for --remove-dead-decls functionality

import XCTest
import SwiftCodeSanKit
import Foundation

// MARK: - Helpers

private func runDeadCodeRemoval(
    files: [String: (content: String, module: String)],
    topDeclsOnly: Bool = false
) -> [String: String] {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("SwiftCodeSanDCETests_\(UUID().uuidString)")
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

    removeDeadDecls(
        filesToModules: filesToModules,
        whitelist: nil,
        topDeclsOnly: topDeclsOnly,
        inplace: true,
        testFiles: nil,
        inplaceTests: false,
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

class DeadCodeTests: XCTestCase {

    // D1: Unused public class (no references anywhere) → REMOVED
    func testD1_UnusedPublicClassRemoved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public class UnusedClass {}
            """, "ModA")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertFalse(content.contains("class UnusedClass"),
                      "D1 FAILED: unused public class was not removed. Got:\n\(content)")
    }

    // D2: Public class used cross-module → PRESERVED
    func testD2_UsedPublicClassPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public class UsedClass {}
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let x = UsedClass()
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("class UsedClass") ?? false,
                      "D2 FAILED: used public class was incorrectly removed.")
    }

    // D4: Function used via member access → PRESERVED
    func testD4_MemberAccessPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public class Provider {
                public func provide() -> Int { 42 }
            }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let p = Provider()
            let x = p.provide()
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("func provide") ?? false,
                      "D4 FAILED: used member function was removed.")
    }

    // D5: Extension member used → PRESERVED
    func testD5_ExtensionMemberPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public class Base {}
            extension Base {
                public func extMethod() {}
            }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let b = Base()
            b.extMethod()
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("func extMethod") ?? false,
                      "D5 FAILED: used extension method was removed.")
    }

    // D6: Dead actor → REMOVED (Verifies our new actor support)
    func testD6_UnusedActorRemoved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public actor UnusedActor {}
            """, "ModA")
        ])
        let content = results["ModA.swift"] ?? ""
        XCTAssertFalse(content.contains("actor UnusedActor"),
                      "D6 FAILED: unused actor was not removed.")
    }

    // D7: Used actor → PRESERVED
    func testD7_UsedActorPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public actor MyActor { public func run() {} }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            func test(a: MyActor) async { await a.run() }
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("actor MyActor") ?? false,
                      "D7 FAILED: used actor was removed.")
    }

    // D8: Typealias used → PRESERVED
    func testD8_UsedTypealiasPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public typealias MyInt = Int
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let x: MyInt = 10
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("typealias MyInt") ?? false,
                      "D8 FAILED: used typealias was removed.")
    }

    // D9: Protocol with used requirement → PRESERVED
    func testD9_UsedProtocolPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public protocol Proto { func req() }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            class C: Proto { func req() {} }
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("protocol Proto") ?? false,
                      "D9 FAILED: used protocol was removed.")
    }

    // D10: Enum used → PRESERVED
    func testD10_UsedEnumPreserved() {
        let results = runDeadCodeRemoval(files: [
            "ModA.swift": ("""
            public enum Status { case ok, error }
            """, "ModA"),
            "ModB.swift": ("""
            import ModA
            let s = Status.ok
            """, "ModB")
        ])
        XCTAssertTrue(results["ModA.swift"]?.contains("enum Status") ?? false,
                      "D10 FAILED: used enum was removed.")
    }
}
