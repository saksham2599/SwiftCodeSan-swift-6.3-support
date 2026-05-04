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

nonisolated(unsafe) private var unusedImports = [String: [String]]()
nonisolated(unsafe) private var total = 0
nonisolated(unsafe) private var whitelistModulesBlock: @Sendable (String) -> Bool = { _ in false }
private let unusedImportsLock = NSLock()

/// A list of well-known system frameworks that should be preserved by default
/// unless they are definitely not used (though proveing "unused" for system
/// frameworks is hard without a full SDK index).
private let defaultSystemFrameworks: Set<String> = [
    "Foundation", "UIKit", "AppKit", "SwiftUI", "Combine", "XCTest",
    "CoreData", "CoreGraphics", "CoreImage", "QuartzCore", "AVFoundation",
    "Metal", "SceneKit", "SpriteKit", "ARKit", "MapKit", "Contacts",
    "AddressBook", "EventKit", "HealthKit", "HomeKit", "CloudKit",
    "PassKit", "Photos", "MediaPlayer", "AddressBookUI", "WebKit",
    "CoreLocation", "CoreMotion", "CoreBluetooth", "ExternalAccessory",
    "NetworkExtension", "QuickLook", "SafariServices", "Social",
    "Accounts", "UserNotifications", "VideoToolbox", "AudioToolbox"
]

public func removeUnusedImports(fileToModuleMap: [String: String],
                                whitelist: Whitelist?,
                                topDeclsOnly: Bool,
                                inplace: Bool,
                                logFilePath: String? = nil,
                                concurrencyLimit: Int? = nil) {
    scanConcurrencyLimit = concurrencyLimit

    let p = DeclParser()
    
    log("Scan all decls and generate a decl map...")
    logTime()

    let allDeclMap = p.scanAndMapDecls(fileToModuleMap: fileToModuleMap,
                                       topDeclsOnly: topDeclsOnly)
    let flatDeclMap = flatten(declMap: allDeclMap)

    logTime()
    log("#Decls", flatDeclMap.keys.count)

    unusedImports = [String: [String]]()
    total = 0

    whitelistModulesBlock = { (module: String) -> Bool in
        let m = module.trimmed
        print("Checking module: '\(m)' against whitelist")
        // Protect default system frameworks
        if defaultSystemFrameworks.contains(m) {
            print("Found in whitelist: \(m)")
            return true
        }

        let moduleComps = module.components(separatedBy: ".").filter {!$0.isEmpty}
        for comp in moduleComps {
            if let list = whitelist?.modules, list.contains(comp) {
                return true
            }
            if let list = whitelist?.modulesSuffix {
                for suffix in list {
                    if comp.hasSuffix(suffix) {
                        return true
                    }
                }
            }
            if let list = whitelist?.modulesPrefix {
                for prefix in list {
                    if comp.hasPrefix(prefix) {
                        return true
                    }
                }
            }
        }
        return false
    }

    log("Check referenced decls and compare their source modules against imported modules to filter out unused imports...")
    p.checkRefs(fileToModuleMap: fileToModuleMap, declMap: flatDeclMap) { @Sendable (filepath, refs, inlinableRefs, imports) in
        var usedImportsInFile = [String: Bool]()
        for i in imports {
            usedImportsInFile[i] = whitelistModulesBlock(i)
        }
        for r in refs {
            if let refDecls = flatDeclMap[r] {
                for refDecl in refDecls {
                    let m = refDecl.module

                    if imports.contains(m) {
                        usedImportsInFile[m] = true
                    } else {
                        let refinedImports = imports.filter {$0.contains(".")}
                        for item in refinedImports {
                            let comps = item.components(separatedBy: ".")
                            if comps.contains(m) {
                                usedImportsInFile[item] = true
                            }
                        }
                    }
                }
            } else {
                // Unknown symbol: could be a system type or a qualified name
                // Case 1: Qualified name (e.g. Foundation.Date)
                for i in imports {
                    if r.hasPrefix("\(i).") {
                        usedImportsInFile[i] = true
                    }
                }

                // Case 2: Exact match for a module name (e.g. usage of Foundation)
                if imports.contains(r) {
                    usedImportsInFile[r] = true
                }
            }
        }

        var unusedListInFile = [String]()
        for (module, used) in usedImportsInFile {
            if !used {
                unusedImportsLock.lock()
                total += 1
                unusedListInFile.append(module)
                unusedImportsLock.unlock()
            }
        }

        if !unusedListInFile.isEmpty {
            unusedImportsLock.lock()
            unusedImports[filepath] = Array(Set(unusedListInFile))
            unusedImportsLock.unlock()
        }
    }

    logTime()
    log("#Unused imports", total)

    if let op = logFilePath {
        log("Save results...")

        var totalUnused = 0
        var ret = unusedImports.map { (path, unusedlist) -> String in
            totalUnused += unusedlist.count
            return path + "\n" + String(unusedlist.count) + "\n" + unusedlist.joined(separator: ", ")
        }
        assert(total == totalUnused)
        ret.append("Total unused: \(totalUnused)")
        let retStr = ret.joined(separator: "\n\n")

        let declstr = flatDeclMap.map{ (k, v) -> String in
            let t = """
            \(k):  \(v.map { $0.path }.joined(separator: ", "))
            """
            return t
        }.joined(separator: "\n")

        try? retStr.write(toFile: op, atomically: true, encoding: .utf8)
        try? declstr.write(toFile: op+"-decls", atomically: true, encoding: .utf8)
    }

    if inplace {
        log("Remove unused imports from files...", unusedImports.keys.count)
        let updater = DeclUpdater()
        updater.removeUnusedImports(fileToModuleMap: fileToModuleMap,
                                    unusedImports: unusedImports) { (path, result) in
                                        try? result.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    logTime()

    logTotalElapsed("Done")
}
